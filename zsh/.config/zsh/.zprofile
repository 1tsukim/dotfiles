eval "$(/opt/homebrew/bin/brew shellenv)"

# trash: keg-only なので個別に PATH 追加（macOS の同名コマンドより前に置く）
export PATH="/opt/homebrew/opt/trash/bin:$PATH"

# Hugging Face: Keychain から取得（GUI セッション必須なので login shell で 1 回だけ）
export HF_TOKEN=$(security find-generic-password -s hf-token -w 2>/dev/null)
