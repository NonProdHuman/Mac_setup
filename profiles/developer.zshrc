# Developer Profile Shell Configurations
alias pre-commit="uv tool run pre-commit"

# Homebrew's OpenJDK is keg-only, so expose java/jar for developer shells.
if [[ -d "/opt/homebrew/opt/openjdk" ]]; then
    export JAVA_HOME="/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home"
    export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"
elif [[ -d "/usr/local/opt/openjdk" ]]; then
    export JAVA_HOME="/usr/local/opt/openjdk/libexec/openjdk.jdk/Contents/Home"
    export PATH="/usr/local/opt/openjdk/bin:$PATH"
fi
