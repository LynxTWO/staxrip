Schema: 1
Encoder: fake
Locale: en
Title: Fake Encoder
Source: Source/Encoding/FakeEnc.vb
Allowed-Missing: 2
Minimum-Reviewed: 3
Reviewed-Complete: false
Verified-Encoder-Version: FakeEnc 1.0
Verified-Encoder-Build: v1.0
Verified-Date: 2026-08-26
Documentation: https://example.invalid/fake/v1.0/Parameters.md

## fake.alpha
Label: Alfa
Summary: Alpha text.
When to change: Rarely.
Values:
- 3: Values on a numeric parameter are an error.
Related: fake.beta, concept.size, fake.nothing
Status: reviewed

## fake.beta
Summary: Beta text.
When to change: Rarely.
Values:
- 1: Turns it on.
- 2: Only the second control emits this.
- 3: Not a value beta has.
Status: reviewed

## fake.gamma
Summary: Gamma text.
Status: draft

## fake.orphan
Summary: No parameter has this id.
Status: draft

## fake.delta
Use: shared.missing
Status: reviewed

## fake.sigma
Summary: Only a grandchild variant declares this switch.
Status: draft
