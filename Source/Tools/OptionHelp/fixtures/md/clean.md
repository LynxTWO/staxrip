# Fake encoder option help

Schema: 1
Encoder: clean
Locale: en
Title: Fake Encoder
Source: Source/Encoding/FakeEnc.vb
Allowed-Missing: 0
Minimum-Reviewed: 2
Reviewed-Complete: false
Verified-Encoder-Version: FakeEnc 1.0
Verified-Encoder-Build: v1.0
Verified-Date: 2026-08-26
Documentation: https://example.invalid/fake/v1.0/Parameters.md

<!-- A comment line is ignored anywhere. -->

## fake.alpha
Label: Alpha
Summary: Controls the first thing. Higher values make the file smaller
  but slower to produce.
Used when: Rate control is Quality.
When to change: Raise it when the file is too large; lower it when the picture looks soft.
Encoder default: 3
Example: Try 2, 3, and 4 on a short clip and compare `--alpha` results.
Values:
- 2: A little sharper and larger.
- 4: Smaller with some loss.
Related: fake.beta, concept.size
References:
- https://example.invalid/fake/v1.0/Parameters.md#alpha
Status: reviewed

## fake.beta
Label: Beta
Summary: Turns the second thing on. See [the guide](https://example.invalid/guide).
When to change: Leave it on unless the encoder warns about it.
Status: reviewed

## fake.gamma
Summary: A draft with only a summary.
Status: draft

## fake.delta
Label: Delta
Use: shared.delta
Status: reviewed
