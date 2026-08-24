Imports System.Collections.Concurrent
Imports System.Reflection
Imports System.Runtime.CompilerServices
Imports System.Runtime.Serialization

''' <summary>
''' Reflection-based deep copier that reproduces <c>BinaryFormatter</c>'s in-memory clone
''' semantics without <c>BinaryFormatter</c>, which is removed from modern .NET.
''' </summary>
''' <remarks>
''' This is not "a serializer that happens to round-trip". It reproduces six specific
''' behaviors the old <c>BinaryFormatter</c> round-trip had, because code in this tree
''' depends on all six and a copier that silently drops one produces an object that looks
''' copied and behaves wrongly:
'''
''' <list type="number">
''' <item>Every field is copied, including private and read-only ones, all the way up the
''' inheritance chain.</item>
''' <item><c>&lt;NonSerialized&gt;</c> fields are skipped and left at their type default.
''' Fields carrying handles, caches or parent links depend on this.</item>
''' <item>Reference identity within the graph is preserved: an object referenced twice is
''' copied once and referenced twice. A tree-walking copier duplicates it and destroys
''' aliasing the original relied on, without raising anything.</item>
''' <item>Cycles terminate, because the identity map is populated before recursing.</item>
''' <item>No constructor runs; instances come from
''' <see cref="FormatterServices.GetUninitializedObject"/>.</item>
''' <item>Serialization callbacks fire in the formatter's order:
''' <c>&lt;OnDeserializing&gt;</c> before the fields land, <c>&lt;OnDeserialized&gt;</c>
''' after, base class before derived, and <see cref="IDeserializationCallback"/> only once
''' the whole graph is built. <c>CustomCultureInfo</c> rebuilds its transient state in one of
''' these and comes back invalid if they are skipped.</item>
''' </list>
'''
''' Verified against <c>BinaryFormatter</c> itself by
''' <c>Docs\Verification\D-053\clone-differential.ps1</c>, which compares clones structurally
''' <em>including aliasing</em> and must report zero differences. See D-053 in the decision
''' log for the reasoning and the measured results.
'''
''' Failure modes are kept identical to the formatter's on purpose: a type that is not marked
''' <c>&lt;Serializable&gt;</c> raises <see cref="SerializationException"/> here just as it
''' did before, rather than being quietly copied into a half-built object. The one deliberate
''' departure is that delegate fields are left <c>Nothing</c> instead of raising, because a
''' clone wants the data and not the event wiring.
'''
''' One limitation worth stating rather than discovering: a serialization callback declared on
''' a <em>structure</em> runs, but anything it assigns to the structure's own fields is lost,
''' because VB cannot hand a boxed value type to <c>MethodInfo.Invoke</c> without copying it.
''' Fields of structures are copied correctly -- see <c>PopulateObjectMembers</c> below -- and
''' every callback in this tree is declared on a class, where this does not arise.
'''
''' The walk is recursive, which suits the wide-and-shallow graphs this is used on
''' (<c>Project</c>, <c>PrimitiveStore</c>, profile objects). It is not intended for graphs
''' thousands of links deep.
''' </remarks>
Public NotInheritable Class DeepCopy

    Private Sub New()
    End Sub

    Private Const MemberFlags As BindingFlags =
        BindingFlags.Instance Or BindingFlags.Public Or BindingFlags.NonPublic Or BindingFlags.DeclaredOnly

    ''' <summary>Returns a deep copy of <paramref name="value"/>.</summary>
    Public Shared Function Clone(Of T)(value As T) As T
        Dim root As Object = value

        If root Is Nothing Then Return Nothing

        Dim map As New Dictionary(Of Object, Object)(ReferenceComparer.Instance)
        Dim pending As New List(Of IDeserializationCallback)

        Dim copy = Walk(root, map, pending)

        ' IDeserializationCallback fires only once the entire graph exists, so implementors
        ' are collected during the walk and drained here, exactly as the formatter did.
        For Each callback In pending
            callback.OnDeserialization(Nothing)
        Next

        If copy Is Nothing Then Return Nothing

        Return DirectCast(copy, T)
    End Function

    Private Shared Function Walk(
        source As Object,
        map As Dictionary(Of Object, Object),
        pending As List(Of IDeserializationCallback)) As Object

        If source Is Nothing Then Return Nothing

        Dim type = source.GetType()

        If IsShared(type) Then Return source

        ' Value types are never entered in the identity map: each box stands alone, which is
        ' unobservable for the immutable structs this walks over.
        Dim existing As Object = Nothing

        If Not type.IsValueType AndAlso map.TryGetValue(source, existing) Then
            Return existing
        End If

        If type.IsArray Then Return WalkArray(DirectCast(source, Array), type, map, pending)

        ' The formatter refuses delegates whose target is not serializable. Dropping the
        ' wiring is the useful behavior for a clone and cannot fail.
        If GetType([Delegate]).IsAssignableFrom(type) Then Return Nothing

        ' Refusing a non-serializable class keeps the old failure loud: a form, a stream or a
        ' process handle reaching a graph raised here before and still does, instead of being
        ' turned into a half-built object that looks copied.
        '
        ' The check deliberately stops at classes. Framework collections hide non-serializable
        ' internal structs -- Dictionary's Entry, Hashtable's bucket -- which the formatter
        ' never met because those types serialize themselves through ISerializable and are
        ' rebuilt from their contents. Copying such a struct field-wise is both correct and
        ' unavoidable here, so structs are exempt.
        If Not type.IsSerializable AndAlso Not type.IsValueType Then
            Throw New SerializationException(
                $"Type '{type.FullName}' is not marked as serializable and cannot be deep-copied.")
        End If

        Dim copy = FormatterServices.GetUninitializedObject(type)

        ' Registered before the fields are walked, so a cycle back to this object finds the
        ' copy instead of recursing forever.
        If Not type.IsValueType Then map(source) = copy

        InvokeCallbacks(copy, type, CallbackKind.Deserializing)

        Dim fields = GetSerializedFields(type)
        Dim values(fields.Length - 1) As Object

        For index = 0 To fields.Length - 1
            values(index) = Walk(fields(index).GetValue(source), map, pending)
        Next

        ' Written through PopulateObjectMembers rather than field by field, because a boxed
        ' structure cannot be filled in from VB: passing an Object variable that holds a value
        ' type makes the compiler emit RuntimeHelpers.GetObjectValue, so every SetValue would
        ' land on a throwaway copy and the structure would come back at its type default. That
        ' failure is silent and vicious -- it is what turns a copied Dictionary's entries array
        ' into a self-referential next chain that hangs the first lookup. Populating in one
        ' call and taking the returned instance keeps the box that was actually written.
        copy = FormatterServices.PopulateObjectMembers(copy, DirectCast(fields, MemberInfo()), values)

        InvokeCallbacks(copy, type, CallbackKind.Deserialized)

        Dim deserializationCallback = TryCast(copy, IDeserializationCallback)

        If deserializationCallback IsNot Nothing Then pending.Add(deserializationCallback)

        Return copy
    End Function

    Private Shared Function WalkArray(
        source As Array,
        type As Type,
        map As Dictionary(Of Object, Object),
        pending As List(Of IDeserializationCallback)) As Object

        Dim elementType = type.GetElementType()
        Dim rank = type.GetArrayRank()

        ' An array of immutable elements has nothing to walk, so the framework's own copy is
        ' both correct and considerably faster. This is the common case: String() and Integer().
        If rank = 1 AndAlso IsShared(elementType) Then
            Dim flat = DirectCast(source.Clone(), Array)
            map(source) = flat
            Return flat
        End If

        Dim lengths(rank - 1) As Integer
        Dim lowerBounds(rank - 1) As Integer

        For dimension = 0 To rank - 1
            lengths(dimension) = source.GetLength(dimension)
            lowerBounds(dimension) = source.GetLowerBound(dimension)
        Next

        Dim copy = Array.CreateInstance(elementType, lengths, lowerBounds)
        map(source) = copy

        If rank = 1 Then
            Dim first = lowerBounds(0)

            For index = first To first + lengths(0) - 1
                copy.SetValue(Walk(source.GetValue(index), map, pending), index)
            Next

            Return copy
        End If

        Dim indices(rank - 1) As Integer
        Array.Copy(lowerBounds, indices, rank)

        For counter = 0L To source.LongLength - 1L
            copy.SetValue(Walk(source.GetValue(indices), map, pending), indices)

            ' Odometer across the dimensions, least significant first.
            For dimension = rank - 1 To 0 Step -1
                indices(dimension) += 1
                If indices(dimension) < lowerBounds(dimension) + lengths(dimension) Then Exit For
                indices(dimension) = lowerBounds(dimension)
            Next
        Next

        Return copy
    End Function

    ''' <summary>
    ''' True for values that can be handed to the copy as-is, either because they are
    ''' immutable or because sharing the one canonical instance is what the formatter did.
    ''' </summary>
    Private Shared Function IsShared(type As Type) As Boolean
        If type.IsPrimitive OrElse type.IsEnum Then Return True

        If type Is GetType(String) OrElse
           type Is GetType(Decimal) OrElse
           type Is GetType(Date) OrElse
           type Is GetType(DateTimeOffset) OrElse
           type Is GetType(TimeSpan) OrElse
           type Is GetType(Guid) OrElse
           type Is GetType(IntPtr) OrElse
           type Is GetType(UIntPtr) OrElse
           type Is GetType(DBNull) Then Return True

        ' Reflection objects are process-wide singletons. Copying one produces something
        ' broken, and the formatter resolved them back to the singleton anyway.
        Return GetType(MemberInfo).IsAssignableFrom(type) OrElse
               GetType(Assembly).IsAssignableFrom(type) OrElse
               GetType([Module]).IsAssignableFrom(type)
    End Function

    Private Enum CallbackKind
        Deserializing
        Deserialized
    End Enum

    Private Shared Sub InvokeCallbacks(target As Object, type As Type, kind As CallbackKind)
        Dim methods As MethodInfo()

        If kind = CallbackKind.Deserializing Then
            methods = DeserializingCallbacks.GetOrAdd(type, AddressOf FindDeserializing)
        Else
            methods = DeserializedCallbacks.GetOrAdd(type, AddressOf FindDeserialized)
        End If

        If methods.Length = 0 Then Exit Sub

        ' A fresh argument array per call: clones happen off the UI thread and Invoke is
        ' handed this array directly.
        Dim arguments As Object() = {New StreamingContext(StreamingContextStates.All)}

        For Each method In methods
            method.Invoke(target, arguments)
        Next
    End Sub

    ' Reflection lookups dominate the cost of a copy and the same handful of types is copied
    ' over and over, so all three are memoised.
    Private Shared ReadOnly FieldsByType As New ConcurrentDictionary(Of Type, FieldInfo())
    Private Shared ReadOnly DeserializingCallbacks As New ConcurrentDictionary(Of Type, MethodInfo())
    Private Shared ReadOnly DeserializedCallbacks As New ConcurrentDictionary(Of Type, MethodInfo())

    ''' <summary>
    ''' Every instance field the formatter would have written, most-derived first. Walking the
    ''' base chain with <c>DeclaredOnly</c> is what reaches private fields on base classes,
    ''' which a plain <c>GetFields</c> silently omits.
    ''' </summary>
    Private Shared Function GetSerializedFields(type As Type) As FieldInfo()
        Return FieldsByType.GetOrAdd(type, AddressOf CollectSerializedFields)
    End Function

    Private Shared Function CollectSerializedFields(type As Type) As FieldInfo()
        Dim fields As New List(Of FieldInfo)
        Dim current = type

        While current IsNot Nothing
            For Each field In current.GetFields(MemberFlags)
                If Not field.IsNotSerialized Then fields.Add(field)
            Next

            current = current.BaseType
        End While

        Return fields.ToArray()
    End Function

    Private Shared Function FindDeserializing(type As Type) As MethodInfo()
        Return FindCallbacks(type, GetType(OnDeserializingAttribute))
    End Function

    Private Shared Function FindDeserialized(type As Type) As MethodInfo()
        Return FindCallbacks(type, GetType(OnDeserializedAttribute))
    End Function

    ''' <summary>
    ''' Callback methods carrying <paramref name="attributeType"/>, base class first, which is
    ''' the order the formatter used.
    ''' </summary>
    Private Shared Function FindCallbacks(type As Type, attributeType As Type) As MethodInfo()
        Dim chain As New List(Of Type)
        Dim current = type

        While current IsNot Nothing
            chain.Insert(0, current)
            current = current.BaseType
        End While

        Dim methods As New List(Of MethodInfo)

        For Each link In chain
            For Each method In link.GetMethods(MemberFlags)
                If method.IsDefined(attributeType, False) Then methods.Add(method)
            Next
        Next

        Return methods.ToArray()
    End Function

    ''' <summary>
    ''' Identity comparer. The graph map must key on reference identity, never on an
    ''' overridden <c>Equals</c>: two equal-but-distinct objects are two objects, and merging
    ''' them would invent aliasing the original never had.
    ''' </summary>
    Private NotInheritable Class ReferenceComparer
        Implements IEqualityComparer(Of Object)

        Public Shared ReadOnly Instance As New ReferenceComparer

        Private Sub New()
        End Sub

        Private Function AreSame(x As Object, y As Object) As Boolean _
            Implements IEqualityComparer(Of Object).Equals

            Return x Is y
        End Function

        Private Function IdentityHash(obj As Object) As Integer _
            Implements IEqualityComparer(Of Object).GetHashCode

            Return RuntimeHelpers.GetHashCode(obj)
        End Function
    End Class

End Class
