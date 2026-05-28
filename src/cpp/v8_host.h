#pragma once
#include <string>
#include <v8.h>
#include <libplatform/libplatform.h>

class V8Host {
public:
    V8Host();
    ~V8Host();

    bool Init(const std::string& js_dir);
    // Evaluate a JS expression/statement in the current context
    bool Eval(const std::string& source, const std::string& origin, std::string& err_out);
    // Load a JS file from js_dir by filename
    bool LoadFile(const std::string& filename, std::string& err_out);
    // Call a global JS function with a single JSON string argument.
    // Returns the JSON-stringified result in result_out, or error in err_out.
    bool Call(const std::string& fn_name, const std::string& arg_json,
              std::string& result_out, std::string& err_out);
    void Shutdown();

private:
    std::unique_ptr<v8::Platform> platform_;
    v8::Isolate* isolate_ = nullptr;
    v8::Persistent<v8::Context> context_;
    std::string js_dir_;

    std::string FormatException(v8::TryCatch& tc, const std::string& origin) const;
    v8::Local<v8::String> ToV8String(const std::string& s) const;
};
