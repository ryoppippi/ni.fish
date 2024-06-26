function ni --description "Use the right package manager"
    switch $argv[1]
        case "--help" "-h"
            _ni_print_help
        case ""
            _ni_install_packages
        case "add"
            _ni_add_packages $argv[2..]
        case "remove"
            _ni_remove_packages $argv[2..]
        case "run"
            _ni_run_packages $argv[2..]
        case \*
            echo "ni: Unknown command or option: \"$argv[1]\"" >&2
            return 1
    end
end

function _ni_find_up --argument-names path
    set files $argv[2..]
    for file in $files
        test -e "$path/$file" && echo $path/$file && return
    end

    test ! -z "$path" || return
    _ni_find_up (string replace --regex -- '/[^/]*$' "" $path) $files
end

function _ni_find_lock_file --argument-names path
    _ni_find_up $path package-lock.json yarn.lock pnpm-lock.yaml bun.lockb
end

function _ni_find_package_json --argument-names path
    _ni_find_up $path package.json
end

function _ni_get_package_manager_name --argument-names path
    set lock_file_path (_ni_find_lock_file $path)
    set package_json_path (test -n "$lock_file_path" && _ni_find_package_json $lock_file_path || _ni_find_package_json $path)

    if test -n "$package_json_path"
        set package_manager_name (cat $package_json_path | string match --entire -r "packageManager" | string replace -r '.*"packageManager": "' '' | string trim | string split @)[1]
        if test -n "$package_manager_name"
            if contains $package_manager_name [npm yarn pnpm bun]
                echo $package_manager_name
                return
            end

            echo "ni: Unknown packageManager: \"$package_manager_name\"" >&2
            return 1
        end
    end

    if test -z "$lock_file_path"
        echo "npm"
        return
    end

    switch (basename $lock_file_path)
        case "package-lock.json"
            echo "npm"
        case "yarn.lock"
            echo "yarn"
        case "pnpm-lock.yaml"
            echo "pnpm"
        case "bun.lockb"
            echo "bun"
    end
end

function _ni_get_package_script_names --argument-names path
    if test -z (which jq)
        return
    end

    set package_json_path (_ni_find_package_json $path)
    if test -z "$package_json_path"
        return
    end

    cat $package_json_path | jq -r '.scripts | keys | .[]'
end

function _ni_exec --argument-names command
    if test -z (which $command)
        echo "ni: Doesn't installed package manager: \"$command\"" >&2
        return 1
    end

    echo "ni: Exec command: $argv"
    eval $argv
end

function _ni_contains_argv --argument-names arguments target
    if string match -q -r -- $target $arguments
        return 0
    end

    if test (count $argv[3..]) -eq 0
        return 1
    else
        _ni_contains_argv $arguments $argv[3..]
    end
end

function _ni_remove_argv --argument-names arguments target
    if test (count $argv[3..]) -eq 0
        echo (string replace -- $target "" $arguments | string trim)
    else
        _ni_remove_argv (string replace -- $target "" $arguments | string trim) $argv[3..]
    end
end

function _ni_replace_argv --argument-names arguments target text
    set replaced (string replace -- $target $text $arguments)
    if test (count $argv[4..]) -eq 0
        echo $replaced
    else
        _ni_replace_argv $replaced $argv[4..]
    end
end

function _ni_print_help
    echo "Usage: ni                      Install all dependencies for a project"
    echo "       ni add <package>        Add dependencies to the project and install"
    echo "       ni remove <package>     Remove dependencies from the project and uninstall"
    echo "       ni run <script>         Run a script defined in the package.json"
    echo "Options:"
    echo "       --help or -h            Print this help message"
end

function _ni_install_packages
    switch (_ni_get_package_manager_name $PWD)
        case "npm"
            _ni_exec npm install
        case "yarn"
            _ni_exec yarn install
        case "pnpm"
            _ni_exec pnpm install
        case "bun"
            _ni_exec bun install
    end
end

function _ni_add_packages
    switch (_ni_get_package_manager_name $PWD)
        case "npm"
            _ni_exec npm install (_ni_replace_argv "$argv" -g --global --dev --save-dev -D --save-dev --optional --save-optional -O --save-optional)
        case "yarn"
            if _ni_contains_argv "$argv" --global -g
                _ni_exec yarn global add (_ni_remove_argv "$argv" --global -g)
            else
                _ni_exec yarn add (_ni_replace_argv "$argv" -D --dev -O --optional)
            end
        case "pnpm"
            _ni_exec pnpm add (_ni_replace_argv "$argv" -g --global --dev --save-dev -D --save-dev --optional --save-optional -O --save-optional)
        case "bun"
            _ni_exec bun add (_ni_replace_argv "$argv" -g --global --dev --development -D --development -O --optional)
    end
end

function _ni_remove_packages
    switch (_ni_get_package_manager_name $PWD)
        case "npm"
            _ni_exec npm uninstall (_ni_replace_argv "$argv" -g --global)
        case "yarn"
            if _ni_contains_argv "$argv" --global -g
                _ni_exec yarn global remove (_ni_remove_argv "$argv" --global -g)
            else
                _ni_exec yarn remove $argv
            end
        case "pnpm"
            _ni_exec pnpm remove (_ni_replace_argv "$argv" -g --global)
        case "bun"
            _ni_exec bun remove (_ni_replace_argv "$argv" -g --global)
    end
end

function _ni_run_packages
    switch (_ni_get_package_manager_name $PWD)
        case "npm"
            if test (count $argv) -le 1
                _ni_exec npm run $argv
            else
                _ni_exec npm run $argv[1] -- $argv[2..]
            end
        case "yarn"
            _ni_exec yarn run $argv
        case "pnpm"
            _ni_exec pnpm run $argv
        case "bun"
            _ni_exec bun run $argv
    end
end
