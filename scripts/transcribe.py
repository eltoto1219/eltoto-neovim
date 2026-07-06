#!/usr/bin/env python3
"""Transcribe wav files with faster-whisper in one-shot or server mode.

Usage: transcribe.py <file.wav> [model]     one-shot
       transcribe.py --serve [model]        read wav paths from stdin, one
                                            JSON response line per path
Default model: "medium" on GPU, "base" on CPU.
GPU initialization or transcription failures fall back to CPU; server mode
keeps the resulting model loaded for subsequent requests.
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


def load_cpu_model(name):
    from faster_whisper import WhisperModel

    return WhisperModel(name or "base", device="cpu", compute_type="int8")


def load_model(name):
    from faster_whisper import WhisperModel

    if cuda_available():
        try:
            model = WhisperModel(name or "medium", device="cuda", compute_type="float16")
            return model, True
        except Exception:
            pass

    return load_cpu_model(name), False


def transcribe(model, wav) -> str:
    segments, _info = model.transcribe(wav, vad_filter=True)
    return " ".join(segment.text.strip() for segment in segments).strip()


def transcribe_with_fallback(model, using_cuda, model_name, wav):
    try:
        return transcribe(model, wav), model, using_cuda
    except Exception as gpu_error:
        if not using_cuda:
            raise

        cpu_model = load_cpu_model(model_name)
        try:
            text = transcribe(cpu_model, wav)
        except Exception as cpu_error:
            raise gpu_error from cpu_error
        return text, cpu_model, False


def main() -> None:
    model_name = sys.argv[2] if len(sys.argv) > 2 else None
    model, using_cuda = load_model(model_name)

    if sys.argv[1] == "--serve":
        for line in sys.stdin:
            path = line.strip()
            if not path:
                continue
            try:
                text, model, using_cuda = transcribe_with_fallback(
                    model, using_cuda, model_name, path
                )
                response = {"text": text}
            except Exception as exc:
                response = {"error": str(exc)}
            print(json.dumps(response), flush=True)
        return

    text, _model, _using_cuda = transcribe_with_fallback(
        model, using_cuda, model_name, sys.argv[1]
    )
    print(text)


if __name__ == "__main__":
    main()
