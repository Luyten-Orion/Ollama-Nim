## A simple module that provides an interface to Ollama's API
import std/[
  options, # Used for optional types
  times    # Used for parsing timestamps
]

#import std/json as stdjson

import pkg/[
  sunny,
  puppy
]

const OllamaHeaders = HttpHeaders(@{"User-Agent": "Ollama-Nim/0.3.0"})

type
  OllmApiError* = object of IOError
    code*: int
    body*: string

  OllmClient* = ref object
    ## Stores data persistent between API calls.
    base*: string = "http://localhost:11434"

  OllmOptions* = object
    mirostat* {.json: "mirostat,omitempty".}: Option[int]
    mirostatEta* {.json: "mirostat_eta,omitempty".}: Option[float]
    mirostatTau* {.json: "mirostat_tau,omitempty".}: Option[float]
    numCtx* {.json: "num_ctx,omitempty".}: Option[int]
    repeatLastN* {.json: "repeat_last_n,omitempty".}: Option[int]
    repeatPenalty* {.json: "repeat_penalty,omitempty".}: Option[float]
    temperature* {.json: "temperature,omitempty".}: Option[float]
    seed* {.json: "seed,omitempty".}: Option[int]
    stop* {.json: "stop,omitempty".}: seq[string]
    tfsZ* {.json: "tfs_z,omitempty".}: Option[float]
    numPredict* {.json: "num_predict,omitempty".}: Option[int]
    topK* {.json: "top_k,omitempty".}: Option[int]
    topP* {.json: "top_p,omitempty".}: Option[float]

  OllmGenerateRequest* = object
    model* {.json: ",required".}: string
    prompt* {.json: ",required".}: string
    images* {.json:",omitempty".}: seq[string]
    format* {.json:",omitempty".}: string
    options* {.json:",omitempty".}: OllmOptions
    sysprompt* {.json:"system,omitempty".}: string
    tmplprompt* {.json: "template,omitempty".}: string
    context* {.json: ",omitempty".}: seq[int]
    stream: bool = false
    raw: bool = false
    keepAlive* {.json: "keep_alive,omitempty".}: string

  OllmGenerateResponse* = object
    model* {.json: ",required".}: string
    createdAtStr {.json: "created_at,required".}: string
    createdAt* {.json: "-".}: DateTime
    response* {.json: ",required".}: string
    case done*: bool
      of true:
        totalDuration* {.json: "total_duration,required".}: int64
        loadDuration* {.json: "load_duration,required".}: int64
        promptEvalDuration* {.json: "prompt_eval_duration,required".}: int64
        evalCount* {.json: "eval_count,required".}: int64
        evalDuration* {.json: "eval_duration,required".}: int64
        context* {.json: ",required".}: seq[int]
      else:
        discard

  OllmRole* = enum
    User = "user", Assistant = "assistant", System = "system"

  OllmMessage* = object
    role* {.json: ",required".}: OllmRole
    content* {.json:",required".}: string
    images* {.json:",omitempty".}: seq[string]

  OllmChatRequest* = object
    model* {.json: ",required".}: string
    messages* {.json: ",required".}: seq[OllmMessage]
    format* {.json:",omitempty".}: string
    options* {.json:",omitempty".}: OllmOptions
    sysprompt* {.json:"system,omitempty".}: string
    tmplprompt* {.json: "template,omitempty".}: string
    context* {.json: ",omitempty".}: seq[int]
    stream: bool = false
    raw: bool = false
    keepAlive* {.json: "keep_alive,omitempty".}: string

  OllmChatResponse* = object
    model* {.json: ",required".}: string
    createdAtStr {.json: "created_at,required".}: string
    createdAt* {.json: "-".}: DateTime
    message*: OllmMessage
    case done*: bool
      of true:
        totalDuration* {.json: "total_duration,required".}: int64
        loadDuration* {.json: "load_duration,required".}: int64
        promptEvalDuration* {.json: "prompt_eval_duration,required".}: int64
        evalCount* {.json: "eval_count,required".}: int64
        evalDuration* {.json: "eval_duration,required".}: int64
      else:
        discard

proc flatten*(msgs: varargs[OllmMessage]): OllmMessage =
  ## Flattens all given messages into a single message. Used for streamed responses, but all message roles must be the same.

  if msgs.len < 0:
    return

  result = msgs[0]

  if msgs.len == 1: return

  for msg in msgs[1..^1]:
    result.content &= msg.content
    result.images &= msg.images

proc fromJson(v: var OllmGenerateResponse, value: JsonValue, input: string) =
  sunny.fromJson(v, value, input)
  v.createdAt = parse(v.createdAtStr, "yyyy-MM-dd'T'HH:mm:ss'.'fffffffffzzz")

proc fromJson(v: var OllmChatResponse, value: JsonValue, input: string) =
  sunny.fromJson(v, value, input)
  v.createdAt = parse(v.createdAtStr, "yyyy-MM-dd'T'HH:mm:ss'.'fffffffffzzz")

proc generate*(client: OllmClient, req: sink OllmGenerateRequest): OllmGenerateResponse =
  ## Makes a request to the Ollama API to generate a response to the given input.
  let resp = post(client.base & "/api/generate", OllamaHeaders, req.toJson)

  if resp.code != 200:
    var err = new(OllmApiError)
    err[] = OllmApiError(msg: "The Ollama API returned the error code " & $resp.code & "! See `body` for more.",
      code: resp.code, body: resp.body)
    raise err

  result = OllmGenerateResponse.fromJson(resp.body)

proc chat*(client: OllmClient, req: sink OllmChatRequest): OllmChatResponse =
  ## Makes a request to the Ollama API to generate a response to the given input.
  let resp = post(client.base & "/api/chat", OllamaHeaders, req.toJson)

  if resp.code != 200:
    var err = new(OllmApiError)
    err[] = OllmApiError(msg: "The Ollama API returned the error code " & $resp.code & "! See `body` for more.",
      code: resp.code, body: resp.body)
    raise err

  result = OllmChatResponse.fromJson(resp.body)