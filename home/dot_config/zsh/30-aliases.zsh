# Aliases that are too machine/repo-specific for ~/.devrc.
alias pinst_token_validation="cd $HOME/Documents/repositories/RectangelHelp/token-validation && find microservices -name 'pyproject.toml' | grep -v '/tests/' | xargs -I {} dirname {} | xargs -I {} -P 4 bash -c 'echo \"Installing dependencies in {}\" && cd \"{}\" && poetry@1 install'"
