---
name: say-to-reut
description: Translate a message (default Russian), speak it with the macOS `say` voice, and send the recording to Reut Beldoch as an audio clip by driving the installed Slack desktop app. Use whenever the user wants to say, voice, record, or send an audio/voice message to Reut (e.g. "/say-to-reut ...", "voice note to reut", "say it to reut in russian"). For plain text messages to Reut use send-to-reut instead.
---

# /say-to-reut

Send a translated, spoken message to Reut Beldoch (Blockaid) through the Slack desktop app. It is the voice sibling of `/send-to-reut`. The message is the same, but it arrives as an audio clip Reut can play inline instead of as text. No Slack token is involved. The script drives the installed app the way you would by hand.

## Parameters

- `lang`: target language for the translation. Default: `russian`.
- `voice`: optional `say` voice name to override the default for the language.
- `message`: the text to speak, taken from whatever follows the command. If it is empty, ask the user what to send and stop.

Example: `/say-to-reut lang=hebrew message=Running five minutes late`

## Steps

1. Parse the arguments and apply the defaults above.
2. Translate `message` into `lang`. Keep the meaning and tone. Output only the translation, which is what gets spoken. Write it so it sounds natural aloud: spell out symbols and abbreviations that a TTS voice would mangle, such as "5 min" → "five minutes" in the target language. For Chinese, use Hanzi only with no pinyin, because a voice would read pinyin out as gibberish. If the message is already in the target language, or is a transliteration of a word from it (for example Hebrew letters spelling a Russian word), write it properly in that language rather than translating its meaning.
3. Write the translation to a temp file, using the session scratchpad if there is one, and run:
   ```bash
   bash ~/.claude/skills/say-to-reut/scripts/slack_ui_send.sh \
     --lang <ru|zh|he|en|…> --text-file <file> [--voice "<name>"]
   ```
   `--lang` takes the two-letter locale prefix (russian→`ru`, chinese→`zh`, hebrew→`he`, english→`en`). The script:
   1. Picks an installed voice (Milena for Russian, Carmit for Hebrew, Samantha for English, a zh_CN voice for Chinese).
   2. Renders the text to `.m4a` under `~/.cache/say-to-reut/`.
   3. Puts the file on the clipboard.
   4. Brings Slack to the front, opens Reut's DM with the quick switcher (Cmd+K → "Reut Beldoch" → Enter), pastes the clip into the composer, and presses Enter.
4. If the cmux-cua tools are available, check the result. Take a `get_window_state` screenshot of the Slack window and confirm that the window title starts with "Reut Beldoch (DM)" and the clip shows as the newest message. If the clip is still sitting unsent in the composer, say so. Do not press Enter again blindly.
5. Confirm in one line: sent to Reut's DM, the language, and the voice. Do not repeat the full text unless the user asks.

## Notes

- **Not a native Slack voice clip.** Slack's recorded clips come from the microphone. This pastes an `.m4a` file, which Slack shows as an inline audio player. Say so if the user asks.
- **It takes over the screen for about 6 seconds.** Slack comes to the front, and keystrokes go to whichever window has focus. Warn the user not to type during the send.
- **Accessibility permission.** The terminal or app running the script needs it (System Settings → Privacy & Security → Accessibility). If `osascript` reports "not allowed to send keystrokes", tell the user to grant it and stop.
- **Thread replies are not supported.** Opening a specific thread through the UI is not reliable. If the user passes a Slack message URL, send to the DM and say it went as a new message, or ask first if the thread matters.
- **Testing.** `--no-send` stops after pasting, so the clip sits in the composer unsent. The user can review it and press Enter themselves.
- If the script fails, report the error and stop. Do not retry more than once, and do not fall back to sending text.
- Do not send anything that was not passed in as `message`.
