using System.Collections.Immutable;
using System.Text.Json.Nodes;

namespace StaxRip.Core;

// The privacy guard for media inspection. The authority's JSON serializes display
// fields, and captured evidence shows it includes globally unique media identifiers,
// encoder settings strings, and filesystem timestamps. None of those describe the media
// in a way this product exposes, and all of them leak something about the user's file
// or machine, so they are stripped from the raw document before normalization reads it.
// The self-test in the contract harness feeds a synthetic document containing every name
// below and fails if any survives; reverting this guard turns that harness red.
public static class MediaFactsPrivacy
{
    // Banned field families. Every entry is the head of a family, not an exact name:
    // the authority splits a single display field across variants, and it adds
    // variants across the supported version range. A measured range-ceiling capture
    // of a real muxer-written file reports Encoded_Application, and beside it
    // Encoded_Application_Name and Encoded_Application_Version, so an exact-name ban
    // strips one third of the same fact. The identifier family already carried this
    // rule; the rest now carry it for the same reason.
    //
    // The suffix-bearing members are kept in the list rather than folded into their
    // family heads, because the self-test and the payload assertions iterate this
    // list and each name must stay individually falsifiable.
    public static ImmutableArray<string> BannedFieldNames { get; } =
    [
        "UniqueID",
        "Encoded_Library_Settings",
        "Encoded_Application",
        "File_Created_Date",
        "File_Created_Date_Local",
        "File_Modified_Date",
        "File_Modified_Date_Local",
        "CompleteName",
        "FolderName",
    ];

    // The family heads, shortest form of each banned name, matched by prefix.
    private static readonly ImmutableArray<string> BannedFieldFamilies =
    [
        "UniqueID",
        "Encoded_Library_Settings",
        "Encoded_Application",
        "File_Created_Date",
        "File_Modified_Date",
        "CompleteName",
        "FolderName",
    ];

    public static bool IsBannedFieldName(string name)
    {
        foreach (string family in BannedFieldFamilies)
        {
            if (name.StartsWith(family, StringComparison.Ordinal))
                return true;
        }

        return BannedFieldNames.Contains(name, StringComparer.Ordinal);
    }

    // Removes every banned member from every object in the document, recursively, so a
    // banned field cannot survive at any nesting depth, including inside "extra" blocks.
    public static void StripBannedFields(JsonNode? node)
    {
        switch (node)
        {
            case JsonObject jsonObject:
                foreach (string name in jsonObject
                    .Select(static member => member.Key)
                    .Where(IsBannedFieldName)
                    .ToArray())
                {
                    jsonObject.Remove(name);
                }

                foreach (KeyValuePair<string, JsonNode?> member in jsonObject)
                    StripBannedFields(member.Value);

                break;

            case JsonArray jsonArray:
                foreach (JsonNode? item in jsonArray)
                    StripBannedFields(item);

                break;
        }
    }
}
