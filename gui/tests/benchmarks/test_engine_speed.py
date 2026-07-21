"""Benchmark Rust engine performance against the Python engine.

This module benchmarks the Rust engine's speed compared to the Python engine for the same queries.
It ensures correctness by verifying that spans (matching positions) are
identical between both engines.
Timings are collected for both cold starts, with Python's memo cache cleared to ensure fairness.
"""
