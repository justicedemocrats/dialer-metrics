use Mix.Config

# In this file, we keep production configuration that
# you'll likely want to automate and keep away from
# your version control system.
#
# You should document the content of this
# file or create a script for recreating it, since it's
# kept out of version control and might be hard to recover
# or recreate for your teammates (or yourself later on).
config :livevox, LivevoxWeb.Endpoint,
  secret_key_base: "BitDdVAQqq8jPp0KBcrU+wyAji1Rn3/X1E51VfBJVpl6ensSM5tYQiwMlAyqGFCa"

config :livevox,
  access_token: "40c206f4423442b0b76d39796498123d",
  clientname: "brandnewcampaign",
  username: "sbriggs",
  password: "3ZBN7g69FD8p"

config :livevox,
  data_dog_api_key: "451d1cce6d3a588ac51bb79f710d2d3d",
  data_dog_application_key: "b5d4c4edf1844a9cb34c9f654e9355d348d8e308",
  airtable_key: "keylEG1YySJXMRa6Z",
  airtable_base: "appYsMtTeDehJmTJb",
  airtable_table_name: "Term%20Codes",
  mongodb_username: "livevox-monitor",
  mongodb_hostname: "ds111123.mlab.com",
  mongodb_password: ",GM7NECUh)3F{Tc^",
  mongodb_port: "11123"

config :livevox,
  claim_info_url: "https://now.justicedemocrats.com/call/who-claimed"
