import asyncio
import aiohttp
from fastapi import FastAPI
import uvicorn
from starlette.middleware.cors import CORSMiddleware
from fastapi.encoders import jsonable_encoder
from pydantic import BaseModel
from fastapi_utils.tasks import repeat_every
from config import API_HOST, API_PORT, ARCHIVE_ENDPOINT


class JsonRpc(BaseModel):
    jsonrpc: str
    method: str
    params: dict
    id: int


class Cache:
    def __init__(self):
        self.cached = {}

    def update(self):
        json_rpc = JsonRpc(jsonrpc="2.0", method="validators.get_next_epoch_set", params={"size": 200}, id=1)
        self.cached["validators.get_next_epoch_set"] = asyncio.run(archive_request(json_rpc))
        print("Updated cache")

    def get(self, method: str):
        return self.cached.get(method)


@repeat_every(seconds=15)
def update_cache():
    cache.update()


cache = Cache()
app = FastAPI(on_startup=[update_cache])
app.add_middleware(
    CORSMiddleware,
    allow_origins=['*'],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


async def archive_request(json_rpc: JsonRpc):
    async with aiohttp.ClientSession() as session:
        async with session.post(ARCHIVE_ENDPOINT, json=jsonable_encoder(json_rpc)) as response:
            return await response.json()


@app.post("/archive")
async def archive(json_rpc: JsonRpc):
    if json_rpc.method == "validators.get_next_epoch_set":
        return cache.get("validators.get_next_epoch_set")
    return await archive_request(json_rpc)


if __name__ == "__main__":
    uvicorn.run(app, host=API_HOST, port=API_PORT)
