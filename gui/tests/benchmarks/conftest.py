"""Shared plumbing for Rust engine benchmarks: build the binary, summarize timings.

This module provides the infrastructure for benchmarking the Rust engine against the Python engine.
It builds the Rust binary in release mode and collects timing data for comparison.
Benchmarks are opt-in (via ``-m benchmark``) to allow for larger target sizes and release builds.
"""
