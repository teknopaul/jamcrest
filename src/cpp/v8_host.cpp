#include "v8_host.h"
#include <fstream>
#include <sstream>
#include <iostream>

V8Host::V8Host() = default;

V8Host::~V8Host() {
    Shutdown();
}

bool V8Host::Init(const std::string& js_dir) {
    js_dir_ = js_dir;
    platform_ = v8::platform::NewDefaultPlatform();
    v8::V8::InitializePlatform(platform_.get());
    v8::V8::Initialize();

    v8::Isolate::CreateParams params;
    params.array_buffer_allocator = v8::ArrayBuffer::Allocator::NewDefaultAllocator();
    isolate_ = v8::Isolate::New(params);

    v8::Isolate::Scope isolate_scope(isolate_);
    v8::HandleScope handle_scope(isolate_);
    v8::Local<v8::Context> ctx = v8::Context::New(isolate_);
    context_.Reset(isolate_, ctx);
    return true;
}

v8::Local<v8::String> V8Host::ToV8String(const std::string& s) const {
    return v8::String::NewFromUtf8(isolate_, s.c_str(),
                                   v8::NewStringType::kNormal,
                                   static_cast<int>(s.size())).ToLocalChecked();
}

std::string V8Host::FormatException(v8::TryCatch& tc, const std::string& origin) const {
    std::ostringstream oss;
    if (tc.Message().IsEmpty()) {
        v8::String::Utf8Value ex(isolate_, tc.Exception());
        oss << origin << ": " << (*ex ? *ex : "(unknown error)");
        return oss.str();
    }
    v8::String::Utf8Value msg(isolate_, tc.Message()->Get());
    v8::String::Utf8Value file(isolate_, tc.Message()->GetScriptResourceName());
    int line = tc.Message()->GetLineNumber(context_.Get(isolate_)).FromMaybe(-1);
    oss << (*file ? *file : origin) << ":" << line << ": " << (*msg ? *msg : "");
    if (!tc.StackTrace(context_.Get(isolate_)).IsEmpty()) {
        v8::Local<v8::Value> st;
        if (tc.StackTrace(context_.Get(isolate_)).ToLocal(&st)) {
            v8::String::Utf8Value stv(isolate_, st);
            if (*stv) oss << "\n" << *stv;
        }
    }
    return oss.str();
}

bool V8Host::Eval(const std::string& source, const std::string& origin,
                  std::string& err_out) {
    v8::Isolate::Scope isolate_scope(isolate_);
    v8::HandleScope handle_scope(isolate_);
    v8::Local<v8::Context> ctx = context_.Get(isolate_);
    v8::Context::Scope context_scope(ctx);
    v8::TryCatch tc(isolate_);

    v8::ScriptOrigin script_origin(ToV8String(origin));
    v8::Local<v8::Script> script;
    if (!v8::Script::Compile(ctx, ToV8String(source), &script_origin).ToLocal(&script)) {
        err_out = FormatException(tc, origin);
        return false;
    }
    v8::Local<v8::Value> result;
    if (!script->Run(ctx).ToLocal(&result)) {
        err_out = FormatException(tc, origin);
        return false;
    }
    return true;
}

bool V8Host::LoadFile(const std::string& filename, std::string& err_out) {
    std::string path = js_dir_ + "/" + filename;
    std::ifstream f(path);
    if (!f.is_open()) {
        err_out = "cannot open: " + path;
        return false;
    }
    std::ostringstream buf;
    buf << f.rdbuf();
    return Eval(buf.str(), path, err_out);
}

bool V8Host::Call(const std::string& fn_name, const std::string& arg_json,
                  std::string& result_out, std::string& err_out) {
    v8::Isolate::Scope isolate_scope(isolate_);
    v8::HandleScope handle_scope(isolate_);
    v8::Local<v8::Context> ctx = context_.Get(isolate_);
    v8::Context::Scope context_scope(ctx);
    v8::TryCatch tc(isolate_);

    // Look up function
    v8::Local<v8::Value> fn_val;
    if (!ctx->Global()->Get(ctx, ToV8String(fn_name)).ToLocal(&fn_val) ||
        !fn_val->IsFunction()) {
        err_out = "global function not found: " + fn_name;
        return false;
    }
    v8::Local<v8::Function> fn = v8::Local<v8::Function>::Cast(fn_val);

    // Parse arg_json into a V8 value
    v8::Local<v8::Value> arg;
    if (!arg_json.empty()) {
        if (!v8::JSON::Parse(ctx, ToV8String(arg_json)).ToLocal(&arg)) {
            err_out = "failed to parse argument JSON";
            return false;
        }
    } else {
        arg = v8::Undefined(isolate_);
    }

    v8::Local<v8::Value> argv[1] = {arg};
    v8::Local<v8::Value> result;
    if (!fn->Call(ctx, ctx->Global(), 1, argv).ToLocal(&result)) {
        err_out = FormatException(tc, fn_name);
        return false;
    }

    // JSON-stringify result
    v8::Local<v8::Value> json_str;
    if (!v8::JSON::Stringify(ctx, result).ToLocal(&json_str)) {
        err_out = "failed to stringify result";
        return false;
    }
    v8::String::Utf8Value utf8(isolate_, json_str);
    result_out = *utf8 ? *utf8 : "null";
    return true;
}

bool V8Host::EvalReturn(const std::string& expr, const std::string& origin,
                        std::string& result_out, std::string& err_out) {
    v8::Isolate::Scope isolate_scope(isolate_);
    v8::HandleScope handle_scope(isolate_);
    v8::Local<v8::Context> ctx = context_.Get(isolate_);
    v8::Context::Scope context_scope(ctx);
    v8::TryCatch tc(isolate_);

    v8::ScriptOrigin script_origin(ToV8String(origin));
    v8::Local<v8::Script> script;
    if (!v8::Script::Compile(ctx, ToV8String(expr), &script_origin).ToLocal(&script)) {
        err_out = FormatException(tc, origin);
        return false;
    }
    v8::Local<v8::Value> result;
    if (!script->Run(ctx).ToLocal(&result)) {
        err_out = FormatException(tc, origin);
        return false;
    }
    v8::Local<v8::Value> json_str;
    if (!v8::JSON::Stringify(ctx, result).ToLocal(&json_str)) {
        err_out = "failed to stringify result";
        return false;
    }
    v8::String::Utf8Value utf8(isolate_, json_str);
    result_out = *utf8 ? *utf8 : "null";
    return true;
}

void V8Host::Shutdown() {
    if (isolate_) {
        context_.Reset();
        isolate_->Dispose();
        isolate_ = nullptr;
        v8::V8::Dispose();
        v8::V8::ShutdownPlatform();
        platform_.reset();
    }
}
