use sqlite.nu *
use base.nu
use data.nu

export def cmpl-sessoin-offset [buffer: string] {
    let session = if NU_ARGX_EXISTS in $env {
        $buffer | argx parse | get -o opt.fork
    }
    let session = if ($session | is-empty) { $env.AI_SESSION } else { $session }
    let w = ((term size).columns / 2 | math floor) - 8
    let c = sqlx $"select substr\(content, 0, ($w)\) as description from messages where session_id = ($session)"
    | enumerate
    | each {|x| {value: ($x.index + 1), description: $x.item.description} }
    { completions: $c, options: { sort: false, partial: false } }
}

def cmpl-models-temp [path buffer] {
    let provider = if NU_ARGX_EXISTS in $env {
        let ctx = $buffer | argx parse
        $ctx | get -o $path
    }
    let s = data session -p $provider
    base ai-models $s
}

export def cmpl-models [buffer: string] {
    cmpl-models-temp ([opt provider] | into cell-path)  $buffer
}

export def cmpl-models-pos [buffer: string] {
    cmpl-models-temp ([pos provider] | into cell-path) $buffer
}

export def cmpl-tools [] {
    $env.AI_TOOLS | columns
}

export def cmpl-previous [] {
    let rw = (term size).columns - 22
    sqlx $"select id as value,
            substr\(
                updated || '│' ||
                type || '|' ||
                printf\('%-20s', args\) || '│' ||
                model || '|' ||
                content,
                0, ($rw)
            \) as description
        from scratch order by updated desc limit 10;"
    | { completions: $in, options: { sort: false } }
}

export def 'cmpl-role' [buffer: string] {
    let args = $buffer | split row '|' | last | str trim -l | split row ' ' | slice 1..
    let len = $args | length
    match $len {
        1 => {
            cmpl-prompt
        }
        _ => {
            let d = sqlx $"select * from prompt where name = (Q $args.0)"
            let d = $d | first | get placeholder | from yaml
            let pos = $len - 2
            let n = $d | get $pos
            sqlx $"select yaml from placeholder where name = (Q $n)"
            | first | get yaml | from yaml | columns
        }
    }
}


def cmpl-config [buffer: string] {
    let ctx = $buffer | split row -r '\s+' | slice 1..
    if ($ctx | length) < 2 {
        return [provider, prompt, function]
    } else {
        sqlx $'select name from ($ctx.0)' | get name
    }
}

export def cmpl-provider [] {
    let current = sqlx $"select provider from sessions where id = ($env.AI_SESSION)"
    | get provider
    sqlx $'select name, active from provider'
    | each {|x|
        let a = if $x.active > 0 {'*'} else {''}
        let c = if $x.name in $current {'+'} else {''}
        {value: $x.name, description: $"($c)($a)"}
    }
}

export def cmpl-prompt [] {
    $env.AI_PROMPTS
    | values
    | select name description
    | rename value
    | insert style {fg: xterm_blue}
    | append (sqlx "select name as value, description from prompt")
    | { completions: $in, options: { sort: false } }
}

export def cmpl-system [] {
    sqlx $"select name from prompt where system != ''"
    | get name
}

export def cmpl-temperature [] {
    let s = data session
    let tr = ($s.temp_max - $s.temp_min) / 5
    0..5 | each { $in * $tr }
}
