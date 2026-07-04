#!/usr/bin/env python3
"""Transcribe a wav file with faster-whisper and print the text to stdout.

Usage: transcribe.py <file.wav> [model]
Models download to ~/.cache/huggingface on first use.
"""
import sys


def main() -> None:
    wav = sys.argv[1]
    model_name = sys.argv[2] if len(sys.argv) > 2 else "base"

    from faster_whisper import WhisperModel

    model = WhisperModel(model_name, device="cpu", compute_type="int8")
    segments, _info = model.transcribe(wav, vad_filter=True)
    print(" ".join(segment.text.strip() for segment in segments).strip())


if __name__ == "__main__":
    main()
