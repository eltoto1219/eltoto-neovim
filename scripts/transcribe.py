#!/usr/bin/env python3
"""Transcribe wav files with faster-whisper and print the text to stdout.

Usage: transcribe.py <file.wav> [model]     one-shot
       transcribe.py --serve [model]        read wav paths from stdin, one
                                            transcript line per path
Default model: "medium" on GPU, "base" on CPU.
Models download to ~/.cache/huggingface on first use.
"""
import sys


def load_model(name):
    from faster_whisper import WhisperModel

    try:
        return WhisperModel(name or "medium", device="cuda", compute_type="float16")
    except Exception:
        return WhisperModel(name or "base", device="cpu", compute_type="int8")


def transcribe(model, wav) -> str:
    segments, _info = model.transcribe(wav, vad_filter=True)
    return " ".join(segment.text.strip() for segment in segments).strip()


def main() -> None:
    model_name = sys.argv[2] if len(sys.argv) > 2 else None

    if sys.argv[1] == "--serve":
        model = load_model(model_name)
        for line in sys.stdin:
            path = line.strip()
            if not path:
                continue
            try:
                text = transcribe(model, path)
            except Exception as exc:  # keep the one-line-per-request protocol
                print(f"transcribe error: {exc}", file=sys.stderr, flush=True)
                text = ""
            print(text, flush=True)
        return

    print(transcribe(load_model(model_name), sys.argv[1]))


if __name__ == "__main__":
    main()
