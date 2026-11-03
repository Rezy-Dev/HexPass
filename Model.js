.pragma library

// Pure helpers for HexPass. Nothing in here touches the store or the UI; the
// controller and panel feed values in and render the results.

var IDENTITY_KEYS = ["username", "user", "login", "email", "account"]
var URL_KEYS = ["url", "website", "link", "site"]
var NOTE_KEYS = ["note", "notes", "comment", "comments"]

function normalizePath(value) {
  return String(value || "").trim().replace(/^\/+|\/+$/g, "")
}

function validatePath(value) {
  var path = normalizePath(value)
  if (!path) return "A path is required"
  if (path.length > 512) return "That path is too long"

  var parts = path.split("/")
  for (var i = 0; i < parts.length; i++) {
    var part = parts[i]
    if (!part || part === "." || part === "..") return "That path is not valid"
  }
  return ""
}

function comparePaths(a, b) {
  return String(a).toLowerCase().localeCompare(String(b).toLowerCase())
}

function parseList(raw) {
  var text = String(raw || "").trim()
  if (!text) return []

  var parsed = null
  try {
    parsed = JSON.parse(text)
  } catch (error) {
    parsed = null
  }

  var values = []
  if (Array.isArray(parsed)) {
    values = parsed
  } else {
    values = text.split("\n")
  }

  var entries = []
  for (var i = 0; i < values.length; i++) {
    var entry = String(values[i] || "").trim()
    if (entry) entries.push(entry)
  }
  entries.sort(comparePaths)
  return entries
}

function filterEntries(entries, query) {
  var needle = String(query || "").trim().toLowerCase()
  var tokens = needle ? needle.split(/\s+/) : []
  var rows = []

  for (var i = 0; i < entries.length; i++) {
    var path = String(entries[i] || "")
    if (!path) continue

    var lower = path.toLowerCase()
    var matches = true
    for (var t = 0; t < tokens.length; t++) {
      if (lower.indexOf(tokens[t]) === -1) {
        matches = false
        break
      }
    }
    if (!matches) continue

    var parts = path.split("/")
    rows.push({
      path: path,
      title: parts[parts.length - 1],
      folder: parts.slice(0, -1).join("/"),
      lower: lower
    })
  }

  rows.sort(function(a, b) {
    var aPath = needle && a.lower.indexOf(needle) === 0 ? 0 : 1
    var bPath = needle && b.lower.indexOf(needle) === 0 ? 0 : 1
    if (aPath !== bPath) return aPath - bPath

    var aTitle = needle && a.title.toLowerCase().indexOf(needle) === 0 ? 0 : 1
    var bTitle = needle && b.title.toLowerCase().indexOf(needle) === 0 ? 0 : 1
    if (aTitle !== bTitle) return aTitle - bTitle

    return a.lower.localeCompare(b.lower)
  })

  return rows
}

function isIdentityLine(line) {
  var match = String(line || "").match(/^([A-Za-z0-9_.-]+):\s*/)
  if (!match) return false
  var key = match[1].toLowerCase()
  return IDENTITY_KEYS.indexOf(key) !== -1 || URL_KEYS.indexOf(key) !== -1
}

function parseEntry(raw, path) {
  var text = String(raw || "").replace(/\r\n/g, "\n")
  var lines = text.split("\n")
  if (lines.length > 0 && lines[lines.length - 1] === "") lines.pop()

  var password = lines.length > 0 ? lines[0] : ""
  var username = ""
  var url = ""
  var otpUrl = ""
  var notes = []
  var extras = []
  var bodyLines = []
  var formLines = []

  for (var i = 1; i < lines.length; i++) {
    var line = lines[i]
    bodyLines.push(line)

    if (isIdentityLine(line)) continue
    formLines.push(line)

    var trimmed = line.trim()
    if (!trimmed) {
      notes.push("")
      continue
    }

    if (/^otpauth:\/\//i.test(trimmed)) {
      if (!otpUrl) otpUrl = trimmed
      continue
    }

    var match = trimmed.match(/^([A-Za-z0-9_.-]+):\s*(.*)$/)
    if (!match) {
      notes.push(line)
      continue
    }

    var key = match[1].toLowerCase()
    var value = match[2].trim()

    if (IDENTITY_KEYS.indexOf(key) !== -1) {
      if (!username) username = value
      continue
    }
    if (URL_KEYS.indexOf(key) !== -1) {
      if (!url) url = value
      continue
    }
    if (NOTE_KEYS.indexOf(key) !== -1) {
      notes.push(value)
      continue
    }
    if (key === "totp" && /^otpauth:\/\//i.test(value)) {
      if (!otpUrl) otpUrl = value
      continue
    }

    extras.push({ key: key, label: match[1], value: value })
  }

  var parts = String(path || "").split("/")
  var title = parts.length > 0 ? parts[parts.length - 1] : ""
  var folder = parts.slice(0, -1).join("/")

  // gopass stores often encode the site and login in the path. Use them when
  // the entry itself has no explicit username/url fields.
  if (!username && title.indexOf("@") > 0) username = title
  if (!url) {
    for (var j = 0; j < parts.length - 1; j++) {
      var part = parts[j]
      if (part.indexOf(".") > 0 && part.indexOf("@") === -1 && !/\s/.test(part)) {
        url = "https://" + part
        break
      }
    }
  }

  var notesText = notes.join("\n").replace(/\n{3,}/g, "\n\n").trim()
  var formNotes = formLines.join("\n").replace(/\n{3,}/g, "\n\n").trim()

  return {
    path: String(path || ""),
    password: password,
    username: username,
    url: url,
    otpUrl: otpUrl,
    notes: notesText,
    extras: extras,
    bodyLines: bodyLines,
    formNotes: formNotes,
    title: title,
    folder: folder
  }
}

function buildSecret(password, username, url, notes) {
  var lines = [String(password || "").replace(/\r?\n/g, " ")]
  if (username) lines.push("username: " + String(username))
  if (url) lines.push("url: " + String(url))

  var body = String(notes || "").replace(/\r\n/g, "\n").replace(/\s+$/g, "")
  if (body) {
    var extra = body.split("\n")
    for (var i = 0; i < extra.length; i++) lines.push(extra[i])
  }

  return lines.join("\n") + "\n"
}

function otpType(url) {
  return /^otpauth:\/\/hotp/i.test(String(url || "")) ? "hotp" : "totp"
}

function otpPeriod(url) {
  var match = String(url || "").match(/[?&]period=(\d+)/i)
  return match ? Math.max(1, parseInt(match[1], 10)) : 30
}

function otpDigits(url) {
  var match = String(url || "").match(/[?&]digits=(\d+)/i)
  return match ? Math.max(1, parseInt(match[1], 10)) : 6
}

function otpWindow(period) {
  return Math.floor(Date.now() / 1000 / Math.max(1, period))
}

function otpRemaining(period) {
  var safe = Math.max(1, period)
  return safe - (Math.floor(Date.now() / 1000) % safe)
}

function formatOtp(code) {
  return String(code || "").replace(/\s+/g, "").replace(/(\d{3})(?=\d)/g, "$1 ")
}

function maskPassword(password) {
  var length = Math.max(8, Math.min(16, String(password || "").length || 12))
  return new Array(length + 1).join("\u2022")
}

function cleanError(raw) {
  var text = String(raw || "").replace(/\x1b\[[0-9;]*m/g, "").trim()
  if (!text) return ""

  var lines = text.split("\n")
  for (var i = lines.length - 1; i >= 0; i--) {
    var line = lines[i].trim()
    if (line) return line
  }
  return ""
}

function prettyRemote(url) {
  var value = String(url || "").trim().replace(/\.git$/i, "")
  if (!value) return ""

  var ssh = value.match(/^[^@]+@([^:]+):(.+)$/)
  if (ssh) return ssh[1] + "/" + ssh[2]

  return value.replace(/^https?:\/\//i, "").replace(/^ssh:\/\//i, "")
}

function parseGitStatus(raw) {
  var lines = String(raw || "").split("\n")
  var first = lines.length > 0 ? lines[0] : ""
  var branch = ""
  var ahead = 0
  var behind = 0
  var dirty = false

  var branchMatch = first.match(/^##\s+([^\s.]+)/)
  if (branchMatch) branch = branchMatch[1]

  var aheadMatch = first.match(/ahead\s+(\d+)/)
  if (aheadMatch) ahead = parseInt(aheadMatch[1], 10)

  var behindMatch = first.match(/behind\s+(\d+)/)
  if (behindMatch) behind = parseInt(behindMatch[1], 10)

  for (var i = 1; i < lines.length; i++) {
    if (lines[i].trim()) {
      dirty = true
      break
    }
  }

  return { branch: branch, ahead: ahead, behind: behind, dirty: dirty }
}

function clipboardSeconds(value) {
  var seconds = Number(value)
  if (!isFinite(seconds) || seconds < 0) return 0
  return Math.min(300, Math.round(seconds))
}
