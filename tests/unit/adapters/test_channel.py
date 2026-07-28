"""The re-entrant line: framing, call/answer pairing, and refusals crossing it."""

from __future__ import annotations

import json
from io import StringIO

import pytest

from hejmark.adapters.channel import Channel, ChannelError, RefusalError, refuse, restore
from hejmark.core.ir.errors import HimarkScopeError


def _sent(writer: StringIO) -> list[dict]:
    """Every message a channel wrote, in order."""
    return [json.loads(line) for line in writer.getvalue().splitlines()]


def _refuse_everything(_channel: Channel, verb: str, _params: dict) -> object:
    """A dispatch that declines whatever it is handed."""
    category, detail = "scope", f"no {verb} here"
    raise RefusalError(category, detail)


def test_call_sends_a_request_and_returns_its_answer() -> None:
    """The plain exchange: one request out, one result back."""
    writer = StringIO()
    reader = StringIO(json.dumps({"id": 1, "ok": {"face": [97]}}) + "\n")

    result = Channel(reader, writer, _refuse_everything).call("zero", {"universe": {}})

    assert result == {"face": [97]}
    assert _sent(writer) == [{"id": 1, "verb": "zero", "params": {"universe": {}}}]


def test_call_services_an_inbound_request_while_it_waits() -> None:
    """Re-entrancy, the protocol's first requirement.

    The far side asks a question of its own before answering ours. An end that
    only listened after it finished talking would deadlock here, and every
    back-reference in the language goes through this path.
    """
    writer = StringIO()
    reader = StringIO(
        json.dumps({"id": 7, "verb": "resolve", "params": {"slot": 0}})
        + "\n"
        + json.dumps({"id": 1, "ok": {"document": []}})
        + "\n"
    )

    def answer(_channel: Channel, _verb: str, params: dict) -> object:
        return {"slot": params["slot"], "universe": {"members": []}}

    result = Channel(reader, writer, answer).call("run", {})

    assert result == {"document": []}
    assert _sent(writer)[1] == {"id": 7, "ok": {"slot": 0, "universe": {"members": []}}}


def test_a_dispatch_that_refuses_answers_with_the_refusal() -> None:
    """A declined request is still an answer -- the far side is never left waiting."""
    writer = StringIO()
    reader = StringIO(json.dumps({"id": 4, "verb": "digits", "params": {}}) + "\n")

    Channel(reader, writer, _refuse_everything).serve()

    assert _sent(writer) == [{"id": 4, "error": {"category": "scope", "message": "no digits here"}}]


def test_a_refused_call_raises_on_the_calling_side() -> None:
    """The refusal is re-raised where the call was made, category intact."""
    reader = StringIO(json.dumps({"id": 1, "error": {"category": "scope", "message": "x"}}) + "\n")

    with pytest.raises(RefusalError) as caught:
        Channel(reader, StringIO(), _refuse_everything).call("run", {})

    assert caught.value.category == "scope"


def test_serve_returns_when_the_far_side_hangs_up() -> None:
    """End of input is how a served engine finishes, not an error."""
    Channel(StringIO(), StringIO(), _refuse_everything).serve()


def test_a_hang_up_mid_call_is_a_channel_error() -> None:
    """An unanswered call is the absence of an answer, never a refusal."""
    with pytest.raises(ChannelError):
        Channel(StringIO(), StringIO(), _refuse_everything).call("run", {})


def test_an_answer_to_a_call_nobody_made_is_refused() -> None:
    """A server that is not waiting on anything has no use for an answer."""
    reader = StringIO(json.dumps({"id": 2, "ok": None}) + "\n")

    with pytest.raises(ChannelError):
        Channel(reader, StringIO(), _refuse_everything).serve()


def test_an_answer_to_the_wrong_call_is_refused() -> None:
    """Ids pair a call with its answer; a mismatch means the two have desynced."""
    reader = StringIO(json.dumps({"id": 9, "ok": None}) + "\n")

    with pytest.raises(ChannelError):
        Channel(reader, StringIO(), _refuse_everything).call("zero", {})


def test_an_answer_that_is_neither_result_nor_refusal_is_refused() -> None:
    """Two answer shapes exist; a third is a malformed conversation."""
    reader = StringIO(json.dumps({"id": 1}) + "\n")

    with pytest.raises(ChannelError):
        Channel(reader, StringIO(), _refuse_everything).call("zero", {})


def test_a_line_that_is_not_a_json_object_is_refused() -> None:
    """Framing is one object per line; anything else stops the conversation."""
    with pytest.raises(ChannelError):
        Channel(StringIO("not json\n"), StringIO(), _refuse_everything).serve()


def test_refuse_names_the_category_of_a_boundary_error() -> None:
    """The wire carries a name, because it cannot carry a class."""
    assert refuse(HimarkScopeError("nothing anchors it")).category == "scope"


def test_refuse_declines_to_name_what_the_wire_cannot() -> None:
    """An error with no category is not relayed as one -- it is left as it was."""
    error = ValueError("something else entirely")

    with pytest.raises(ValueError, match="something else entirely"):
        refuse(error)


def test_restore_returns_the_exception_the_far_side_raised() -> None:
    """A refused program raises the same error it would have raised in process."""
    assert isinstance(restore(RefusalError("scope", "nothing anchors it")), HimarkScopeError)


def test_restore_keeps_a_category_it_does_not_know() -> None:
    """A host that has not heard of a category must not pretend that it has.

    The name here is deliberately not one of ``CATEGORIES``: a category the
    reader does not know stays unread, so a newer engine naming a refusal this
    host has never seen surfaces as the wire error it is rather than as the
    wrong exception.
    """
    unknown = RefusalError("nonesuch", "a refusal from a later protocol")

    assert restore(unknown) is unknown
