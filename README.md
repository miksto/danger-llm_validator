### Danger LLM Validator

Write rules in natural language, and let an LLM ensure they are followed.
You can either run the LLM locally, such as with Ollama, or use one of the OpenAI models.

<blockquote>Basic setup using gpt-4o-mini from OpenAI as the LLM
  <pre>llm_validator.configure_api do |config|
  config.access_token = ENV.fetch("OPENAI_ACCESS_TOKEN")
end
llm_validator.llm_model = "gpt-4o-mini"
llm_validator.checks = ["Comments in the code do not state obviously incorrect things"]
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

`warn_for_validation_errors` - Whether a warning should be posted if any of the validations failed. Defaults to true.

`warn_for_llm_comments` - Whether a warning should be posted for comments received from the LLM. Defaults to true.




#### Methods

`configure_api` - Configure the OpenAI library to connect to the desired API endpoints etc.
See https://github.com/alexrudall/ruby-openai for more details on what parameters can be configured.

`check` - Run the validation. Loops over all hunks in the git diff, and prompts the LLM to validate it.
Creates warnings for all comments received from the LLM.


## Installation

    $ gem install danger-llm_validator

## Usage

    Methods and attributes from this plugin are available in
    your `Dangerfile` under the `llm_validator` namespace.

## Development

1. Clone this repo
2. Run `bundle install` to setup dependencies.
3. Run `bundle exec rake spec` to run the tests.
4. Use `bundle exec guard` to automatically have tests run as you make changes.
5. Make your changes.
