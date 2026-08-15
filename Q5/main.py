import os

from fastapi import FastAPI
from fastapi.responses import PlainTextResponse

app = FastAPI()

APP_VERSION = os.getenv("APP_VERSION", "dev")


@app.get("/", response_class=PlainTextResponse)
def hello_world():
    return f"Hello, World!\nVersion: {APP_VERSION}\n"


@app.get("/healthz", response_class=PlainTextResponse)
def healthz():
    return "ok\n"
