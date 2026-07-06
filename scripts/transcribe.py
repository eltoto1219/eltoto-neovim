#!/usr/bin/env python3
"""Transcribe wav files with faster-whisper and print the text to stdout.

Usage: transcribe.py <file.wav> [model]     one-shot
       transcribe.py --serve [model]        read wav paths from stdin, one
                                            JSON response line per path
Default model: "medium" on GPU, "base" on CPU.
Models download to ~/.cache/huggingface on first use.
"""
import json
import sys


def cuda_available() -> bool:
    try:
        import ctranslate2

        return ctranslate2.get_cuda_device_count() > 0
    except Exception:
        return False


def load_model(name):
    from faster_whisper import WhisperModel

    if cuda_available():
        try:
            return WhisperModel(name or "medium", device="cuda", compute_type="float16")
        except Exception:
            pass

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
                response = {"text": text}
            except Exception as exc:
                response = {"error": str(exc)}
            print(json.dumps(response), flush=True)
        return

    print(transcribe(load_model(model_name), sys.argv[1]))


if __name__ == "__main__":
    main()
