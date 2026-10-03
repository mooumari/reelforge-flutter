#!/usr/bin/env python3
"""Voices a scene's lines with Azure neural TTS.

    tool/.venv/bin/python tool/voice.py example/voices/savanna.json

The script names a cast (each with an Azure voice, and optionally a style,
rate and pitch) and their lines. For every line this writes a WAV and its
timings -- the visemes and word boundaries Azure reports as it speaks -- and
then a Dart file declaring each line as a `Line`, so a composition can lay
its dialogue out from how long each line really takes.

A line is only sent to Azure when its text or voice has changed: the hash of
its SSML is kept beside the audio. The WAVs and the Dart file are meant to be
committed, so rendering never needs the network or a key.

Reads AZURE_SPEECH_KEY and AZURE_SPEECH_REGION from the environment or from
the repository's .env. Needs the Speech SDK: `python3 -m venv tool/.venv &&
tool/.venv/bin/pip install azure-cognitiveservices-speech`.
"""

import hashlib
import json
import os
import re
import sys
from pathlib import Path
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parent.parent


def load_env():
    env = ROOT / ".env"
    if not env.exists():
        return
    for line in env.read_text().splitlines():
        m = re.match(r"\s*([A-Z_][A-Z0-9_]*)\s*=\s*(.*?)\s*$", line)
        if m and m.group(1) not in os.environ:
            os.environ[m.group(1)] = m.group(2).strip("'\"")


def ssml(actor, text):
    voice = actor["voice"]
    lang = "-".join(voice.split("-")[:2])
    body = escape(text)
    prosody = {k: actor[k] for k in ("rate", "pitch") if k in actor}
    if prosody:
        attrs = " ".join(f'{k}="{v}"' for k, v in prosody.items())
        body = f"<prosody {attrs}>{body}</prosody>"
    if "style" in actor:
        degree = actor.get("styledegree", 1)
        body = f'<mstts:express-as style="{actor["style"]}" styledegree="{degree}">{body}</mstts:express-as>'
    return (
        f'<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" '
        f'xmlns:mstts="https://www.w3.org/2001/mstts" xml:lang="{lang}">'
        f'<voice name="{voice}">{body}</voice></speak>'
    )


def synthesize(markup, wav):
    import azure.cognitiveservices.speech as speechsdk

    config = speechsdk.SpeechConfig(subscription=os.environ["AZURE_SPEECH_KEY"], region=os.environ["AZURE_SPEECH_REGION"])
    config.set_speech_synthesis_output_format(speechsdk.SpeechSynthesisOutputFormat.Riff48Khz16BitMonoPcm)
    config.set_property(speechsdk.PropertyId.SpeechServiceResponse_RequestWordBoundary, "true")
    synth = speechsdk.SpeechSynthesizer(speech_config=config, audio_config=speechsdk.audio.AudioOutputConfig(filename=str(wav)))
    visemes, words = [], []
    synth.viseme_received.connect(lambda e: visemes.append({"audioOffset": e.audio_offset, "visemeId": e.viseme_id}))

    def word(e):
        if e.boundary_type == speechsdk.SpeechSynthesisBoundaryType.Word:
            words.append({"audioOffset": e.audio_offset, "duration": int(e.duration.total_seconds() * 1e7), "text": e.text})

    synth.synthesis_word_boundary.connect(word)
    result = synth.speak_ssml_async(markup).get()
    if result.reason != speechsdk.ResultReason.SynthesizingAudioCompleted:
        details = result.cancellation_details
        sys.exit(f"Azure could not voice {wav.name}: {details.reason} {details.error_details}")
    del synth  # closes the file
    return {"seconds": result.audio_duration.total_seconds(), "visemes": visemes, "words": words}


def snake(name):
    return re.sub(r"(?<!^)(?=[A-Z])", "_", name).lower()


def dart_string(s):
    s = s.replace("\\", "\\\\").replace("$", "\\$")
    if "'" in s and '"' not in s:
        return '"' + s + '"'
    return "'" + s.replace("'", "\\'") + "'"


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    load_env()
    script_path = Path(sys.argv[1]).resolve()
    script = json.loads(script_path.read_text())
    project = script_path.parent.parent  # example/voices/x.json -> example/
    out = project / script["audio"]
    out.mkdir(parents=True, exist_ok=True)

    voiced = {}
    for name, line in script["lines"].items():
        actor = script["cast"][line["who"]]
        markup = ssml(actor, line["text"])
        digest = hashlib.sha256(markup.encode()).hexdigest()[:16]
        wav, timings = out / f"{snake(name)}.wav", out / f"{snake(name)}.json"
        cached = json.loads(timings.read_text()) if timings.exists() and wav.exists() else None
        if cached and cached.get("hash") == digest:
            voiced[name] = cached
            print(f"  {name}: unchanged")
            continue
        if not os.environ.get("AZURE_SPEECH_KEY") or not os.environ.get("AZURE_SPEECH_REGION"):
            sys.exit("Set AZURE_SPEECH_KEY and AZURE_SPEECH_REGION, in the environment or .env.")
        data = synthesize(markup, wav)
        data["hash"] = digest
        timings.write_text(json.dumps(data, indent=1) + "\n")
        voiced[name] = data
        print(f"  {name}: {data['seconds']:.2f}s, {len(data['words'])} words, {len(data['visemes'])} visemes")

    cls = script["class"]
    rel = os.path.relpath(out, project)
    lines = [
        f"// Generated by tool/voice.py from {os.path.relpath(script_path, ROOT)}. Do not edit:",
        "// change the script and run the tool again.",
        "",
        "import 'package:reelforge_stage/reelforge_stage.dart';",
        "",
        f"/// The voiced lines of {script_path.stem}.",
        f"abstract final class {cls} {{",
    ]
    for name, line in script["lines"].items():
        d = voiced[name]
        visemes = ", ".join(f"({v['audioOffset']}, {v['visemeId']})" for v in d["visemes"])
        words = ", ".join(f"({w['audioOffset']}, {w['duration']}, {dart_string(w['text'])})" for w in d["words"])
        lines += [
            f"  /// {line['who'].capitalize()}: \"{line['text']}\"",
            f"  static const Line {name} = Line(",
            f"    text: {dart_string(line['text'])},",
            f"    audio: '{rel}/{snake(name)}.wav',",
            f"    seconds: {d['seconds']:.4f},",
            f"    visemes: <(int, int)>[{visemes}],",
            f"    words: <(int, int, String)>[{words}],",
            "  );",
            "",
        ]
    lines[-1] = "}"
    dart = project / script["dart"]
    dart.write_text("\n".join(lines) + "\n")
    print(f"Wrote {os.path.relpath(dart, ROOT)}")


if __name__ == "__main__":
    main()
