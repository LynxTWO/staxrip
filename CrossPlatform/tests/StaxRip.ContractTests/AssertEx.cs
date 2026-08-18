namespace StaxRip.ContractTests;

internal sealed class TestContext
{
    public int AssertionCount { get; private set; }

    public void Equal<T>(T expected, T actual, string message)
    {
        AssertionCount++;
        if (!EqualityComparer<T>.Default.Equals(expected, actual))
            throw new TestFailureException(message, expected, actual);
    }

    public void True(bool condition, string message)
    {
        AssertionCount++;
        if (!condition)
            throw new TestFailureException(message, true, false);
    }

    public void False(bool condition, string message) => True(!condition, message);

    public void SequenceEqual<T>(IEnumerable<T> expected, IEnumerable<T> actual, string message)
    {
        AssertionCount++;
        if (!expected.SequenceEqual(actual))
            throw new TestFailureException(message, string.Join(",", expected), string.Join(",", actual));
    }

    public TException Throws<TException>(Action action, string message)
        where TException : Exception
    {
        AssertionCount++;
        try
        {
            action();
        }
        catch (TException exception)
        {
            return exception;
        }

        throw new TestFailureException(message, typeof(TException).Name, "no exception");
    }
}

internal sealed class TestFailureException : Exception
{
    public TestFailureException(string message, object? expected, object? actual)
        : base($"{message}; expected={Bound(expected)} actual={Bound(actual)}")
    {
    }

    private static string Bound(object? value)
    {
        string text = value?.ToString() ?? "<null>";
        return text.Length <= 160 ? text : text[..160];
    }
}
