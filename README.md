### Danger LLM Validator

Write rules in natural language, and let an LLM ensure they are followed.
You can either run the LLM locally, such as with Ollama, or use one of the OpenAI models.

<blockquote>Basic setup using gpt-4o-mini from OpenAI as the LLM
  <pre>llm_validator.configure_api do |config|
  config.access_token = ENV.fetch("OPENAI_ACCESS_TOKEN")
end
llm_validator.checks = ["Comments in the code do not state obviously incorrect things"]
llm_validator.llm_model = "gpt-4o-mini"
llm_validator.check</pre>
</blockquote>

<blockquote>Basic setup using a locally running LLM served by Ollama
  <pre>llm_validator.configure_api do |config|
   config.uri_base = "http://127.0.0.1:11434"
end
llm_validator.checks = ["Comments in the code do not state obviously incorrect things"]
llm_validator.llm_model = "llama3"
llm_validator.check</pre>
</blockquote>

<blockquote>To filter what files are included or excluded from validation
  <pre>llm_validator.include_patterns = ["*.kt"]
llm_validator.exclude_patterns = ["src/**/*.rb"]</pre>
</blockquote>



#### Attributes

`checks` - An array of checks for the LLM to validate the code changes against.

`llm_model` - The identifier of the language model to use for validation.

`temperature` - The temperature setting for the language model, controlling the randomness of the output.
A lower value results in more deterministic output, while a higher value allows for more creativity.
Defaults to 0.0 for a deterministic output.

`diff_context_extra_lines` - The number of additional context lines to include around each change in a diff.
This can help the model understand the context of the changes better.

`include_patterns` - An array of glob patterns for files to include in the validation.

`exclude_patterns` - An array of glob patterns for files to exclude from the validation.

`llm_responses` - An array of all LLM responses that were received during validation.
Includes extra data such as file paths and the prompt supplied to the LLM as well as the raw response from the LLM.

`validation_errors` - An array debug messages for any error that occurred during validation.

`warn_for_validation_errors` - Whether a warning should be posted if any of the validations resulted in an error. Defaults to true.

`warn_for_llm_comments` - Whether a warning should be posted for comments received from the LLM. Defaults to true.

`system_prompt_template` - Allows you to customize the system prompt for the LLM. Typically used to set overall behavior, tone, and rules for how the AI model.
Supported place holders are `{{CHECKS}}`, `{{JSON_FORMAT}}`, `{{FILE_PATH}}` and `{{CONTENT}}`.

`user_prompt_template` - Allows you to customize the user prompt for the LLM. Typically used to provide a specific input or question to the AI.
Supported place holders are `{{CHECKS}}`, `{{JSON_FORMAT}}`, `{{FILE_PATH}}` and `{{CONTENT}}`.




#### Methods

`configure_api` - Configure the OpenAI library to connect to the desired API endpoints etc.
See https://github.com/alexrudall/ruby-openai for more details on what parameters can be configured.

`check` - Run the validation. Loops over all hunks in the git diff, and prompts the LLM to validate it.
Creates warnings for all comments received from the LLM.


## Usage

Add the following your gemfile

    gem "danger-llm_validator", git: 'https://github.com/miksto/danger-llm_validator.git'

Methods and attributes from this plugin are available in your `Dangerfile` under the `llm_validator` namespace.

### Custom Prompt Templates

You can customize the behavior and responses of the LLM by providing your own `system_prompt_template` and `user_prompt_template` attributes to tailor it to your needs.

The default values for the prompts are as follows:

#### Default System Prompt Template    

    "You are an expert coder who performs code reviews of a pull request in GitHub.\n" \
      "Your ONLY task is to ensure that the following statements are adhered to:\n" \
      "{{CHECKS}}\n\n" \
      "If no violations are found, respond with an empty comments array.\n" \
      "Each line between CONTENT_BEGIN and CONTENT_END is prefixed with the line number.\n" \
      "You must respond with this JSON format:\n" \
      "{{JSON_FORMAT}}\n"

#### Default User Prompt Template
    DEFAULT_USER_PROMPT_TEMPLATE = "METADATA_BEGIN\nfile_path: {{FILE_PATH}}\nMETADATA_END\nCONTENT_BEGIN\n{{CONTENT}}CONTENT_END\n"

By setting any of `system_prompt_template` and `user_prompt_template` to `nil` you can exclude that message from the prompt.


## Development

1. Clone this repo
2. Run `bundle install` to setup dependencies.
3. Run `bundle exec rake spec` to run the tests.
4. Use `bundle exec guard` to automatically have tests run as you make changes.
5. Make your changes.
