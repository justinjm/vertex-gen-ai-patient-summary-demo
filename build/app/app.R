# app.R -----------------------------------------------------------------------
## load packages ------------------------------------------------------------
library(shiny)
library(shinyjs)
library(bslib)
library(bsicons)
library(firebase)
library(shinybusy)
library(markdown)
library(glue)
library(bigrquery)
library(googleCloudVertexAIR)

## debugging  ---------------------------------------------------------------
### set verbose logging when debugging
# options(gargle_verbosity = "debug")
# options(googleAuthR.verbose = 2)

# custom_env_args
## TODO add if does not exist, cat(file = stderr(), "no secrets file")
source("../../secrets/.secrets.R")

## print to stderr so shows in Cloud Logging 
cat(file = stderr(), "> email:", email <- Sys.getenv("GAR_AUTH_EMAIL"), "\n")
cat(file = stderr(), "> project_id:", project_id <- Sys.getenv("PROJECT_ID"), "\n")
cat(file = stderr(), "> region:", region <- Sys.getenv("REGION"), "\n")
cat(file = stderr(), "> bq dataset_id:", dataset_id <- Sys.getenv("DATASET_ID"), "\n")

## authenticate ------------------------------------------------------------
## function to choose auth based on where app running, can run on local machine
## and in cloud run without code changes 
custom_google_auth <- function() {
  sysname <- Sys.info()[["sysname"]]
  cat(file = stderr(), paste0("> sysname: ", sysname), "\n")
  if (sysname == "Linux") {
    googleAuthR::gar_gce_auth()
  } 
  if (sysname == "Darwin") {
    googleAuthR::gar_auth(email = email,
                          scopes = "https://www.googleapis.com/auth/cloud-platform")
  }
  else {
    cat("Not running on Linux or macOS, aborting auth...")
  }
}
custom_google_auth()

## check if token exists after auth for debugging purposes
cat(file = stderr(), paste0("> gar token exists: ", googleAuthR::gar_has_token()), "\n")

## pre-load list of patients to populate first user input 
patients_query_response <- bq_project_query(
  project_id,
  query = glue("SELECT patient_id, name, primary_reason_of_visit FROM `{project_id}.{dataset_id}.patients_user_input`")
)
patients <- bq_table_download(patients_query_response)

## javascript functions 
### listen for enter key on modal to submit login for better UX  
js <- '
$(document).keyup(function(event) {
    if ($("#password_signin").is(":focus") && (event.keyCode == 13) ||
        $("#email_signin").is(":focus") && (event.keyCode == 13)) {
        $("#signin").click();
    }
});
'

# firebase modals ---------------------------------------------------
sign_in <- modalDialog(
  tags$script(HTML(js)),
  title = "Sign in",
  textInput("email_signin", "Email"),
  passwordInput("password_signin", "Password"),
  actionButton("signin", "Sign in")
)

## ui -----------------------------------------------------------------------
ui <- page_sidebar(
  # scriptHeaders(),
  useShinyjs(),
  useFirebase(),
  theme = bs_theme(version = 5),
  tags$head(
    tags$style(
      HTML(".shiny-notification {
             position:fixed;
             top: 0;
             left: 50%;
             transform: translateX(-50%);
             width: 400px;
             }"
      )
    )
  ),
  add_busy_bar(color ="#4284F4", height = "6px"),
  title = "Synthea Patient Summary Demo",
  sidebar = sidebar(
    width = 400,
    accordion(
      id = "accordian-signin-signout",
      accordion_panel(
        title = "Sign in/out",
        icon = bs_icon("box-arrow-in-right"),
        reqSignout(
          actionButton(inputId = "signin_modal", 
                       label = HTML("<b>Sign in</b>"), 
                       style = "color: white; background-color: #4284F4;"
          )
        ),
        reqSignin(
          actionButton("signout", HTML("<b>Sign out</b>"),
                       style = "color: white; background-color: #E7001D;"
          )
        )
      )
    ),
    reqSignin(
      accordion(
        id = "accordian-how-to-use",
        accordion_panel(
          title = "How to use",
          icon = bs_icon("info-circle-fill"),
          p("1. Select the patient's name then click 'Get Patient History'",
            br(),
            "2. Verify the expected patient history then click 'Generate Patient Summary' to generate a summary for the previous 2 years",
            br(),
            "3. To regenerate a patient's summary in a different format, edit the 'Prompt' field below then click 'Generate Patient Summary' again."),
        ),
        open = FALSE
      ),
      accordion(
        id = "accordian-select-patient",
        accordion_panel(
          title = "Select Patient",
          icon = bs_icon("person-fill"),
          selectInput(inputId = "patient_name", 
                      label = "Patient name:",
                      choices = patients$name,
                      selected ="Cristian531 Alarcón922")
        )
      ),
      accordion(
        id = "accordian-get-patient-data",
        accordion_panel(
          title = "Get Patient History and Summary",
          icon = bs_icon("cloud-arrow-down-fill"),
          actionButton(inputId = "get_patient_history", 
                       label = "Get Patient History",
                       style = "color: white; background-color: #4284F4;"
          ),
          br(),
          actionButton(inputId = "get_summary",
                       label = "Generate Patient Summary",
                       style = "color: white; background-color: #4284F4;"
          ),
        ), 
        open = TRUE
      ),
      accordion(
        id = "accordian-user-prompt",
        accordion_panel(
          title = "Prompt Settings", 
          icon = bs_icon("pen-fill"),
          textAreaInput("user_prompt", 
                        "Prompt:",
                        value =  "You are a nurse and I am a doctor. Summarize the patient's registration and medical history below into 500 words or less. Create 2 sections, one for each important point with a brief summary of that point to help me prepare me for the patient's appointment. Create a third section as a markdown heading to highlight the Primary Reason of Visit.",
                        height = "300px"),
          actionButton("reset_user_prompt", 
                       "Reset to default",
                       style = "padding: 4px 8px; font-size: 12px;")
        ),
        open = FALSE
      ),
      accordion(
        id = "dev-settings",
        accordion_panel(
          title = "Developer Settings", 
          icon = bs_icon("gear-fill"),
          sliderInput("temperature", "Temperature", min = 0.1, max = 1.0, value = 0.2, step = 0.1), # default value = 0.2
          sliderInput("max_length", "Maximum Length", min = 1, max = 1024, value = 256, step = 1),
          sliderInput("top_k", "Top-K", min = 1, max = 40, value = 40, step = 1), 
          sliderInput("top_p", "Top-P", min = 0, max = 1, value = 0.8, step = 0.01), # default value = 0.8
          actionButton("reset_dev_settings", 
                       "Reset to default",
                       style = "padding: 4px 8px; font-size: 12px;")
        ),
        open = FALSE
      )
    ),
    tags$div(
      class = "sidebar-text-learn-more",
      style = "font-size: 12px;", 
      HTML(
        "Learn More: <br/> 
         <a href='https://cloud.google.com/vertex-ai/docs/generative-ai/text/test-text-prompts#generative-ai-test-text-prompt-drest' target='_blank'>Vertex AI GenAI Text Prompts</a> <br/>
         <a href='https://console.cloud.google.com/marketplace/product/mitre/synthea-fhir' target='_blank'>FHIR Synethea BigQuery dataset</a> <br/>
           ")
    ),
  ),
  reqSignin(
    navset_card_tab(
      id = "tabs",
      nav_panel(title = "Patient Summary", 
                card(uiOutput("summary")), value = "tab1"),
      nav_panel(title = "2 Year Patient History", 
                card(uiOutput("p2yr_patient_history_ui")), value = "tab2"),
      nav_panel(title = "Full Patient History", 
                card(htmlOutput("full_patient_history_ui")), value = "tab3"),
      nav_panel(title = "WebMD Search",
                card(htmlOutput("iframe_webmd_search")), value = "tab4")
    )
  )
)

## server ------------------------------------------------------------------
server <- function(input, output, session) {
  
  f <- FirebaseEmailPassword$new(persistence = "session") # none or local
  
  # open modal
  observeEvent(input$signin_modal, {
    showModal(sign_in)
  })
  
  # close model after sign in & update accordian sidebar
  observeEvent(input$signin, {
    removeModal()
    accordion_panel_close(id = "accordian-signin-signout", values = TRUE)
    f$sign_in(input$email_signin, input$password_signin)
  })
  
  # show notification for login success / failure 
  # https://github.com/JohnCoene/firebase/issues/24#issuecomment-1256475861
  observeEvent(input$fireblaze_signed_up_user, {
    if (!is.null(input$fireblaze_signed_up_user$response$code)) {
      showNotification("Sign in failed! Incorrect email/password.", type = "error")
    } else {
      showNotification("Sign in successful!", type = "message")
    }
  })
  
  # get full patient history 
  full_patient_history <- eventReactive(input$get_patient_history, {
    selected_patient_id <- patients$patient_id[patients$name == input$patient_name]
    query <- glue("SELECT patient_id, text_registration, text_history FROM `{project_id}.{dataset_id}.patient_all` WHERE patient_id = '{selected_patient_id}'")
    query_job <- bq_project_query(project_id, query = query)
    bq_response <- bq_table_download(query_job)
    return(bq_response)
  })
  
  # get previous 2 years patient history since in a different table
  p2yr_patient_history <- eventReactive(input$get_patient_history, {
    selected_patient_id <- patients$patient_id[patients$name == input$patient_name]
    query <- glue("SELECT patient_id, text_registration, text_history FROM `{project_id}.{dataset_id}.patient_all_2yrs` WHERE patient_id = '{selected_patient_id}'")
    query_job <- bq_project_query(project_id, query = query)
    bq_response <- bq_table_download(query_job)
    return(bq_response)
  })
  
  # outut for full patient history 
  output$full_patient_history_ui <- renderText({
    f$req_sign_in()
    full_patient_history <- full_patient_history()
    
    text <- paste("<b>Patient Registration:</b>",
                  full_patient_history$text_registration,
                  "<b>Patient History:</b>",
                  full_patient_history$text_history,
                  sep = "<br><br>")
    # replace any newline characters with break to to be in proper html format
    htmlText <- gsub("\n", "<br>", text)
    HTML(htmlText)
  })
  
  # load response in background so user action completes without viewing tab
  outputOptions(output, "full_patient_history_ui", suspendWhenHidden = FALSE)
  
  output$p2yr_patient_history_ui <- renderText({
    f$req_sign_in()
    p2yr_patient_history <- p2yr_patient_history()
    
    text <- paste("<b>Patient Registration:</b>",
                  p2yr_patient_history$text_registration,
                  "<b>Patient History:</b>",
                  p2yr_patient_history$text_history,
                  sep = "<br><br>")
    # replace any newline characters with break to to be in proper html format
    htmlText <- gsub("\n", "<br>", text)
    HTML(htmlText)
  })
  
  # load response in background so user action completes without viewing tab
  outputOptions(output, "p2yr_patient_history_ui", suspendWhenHidden = FALSE)
  
  # set summary default text for patient summary (non-user facing)
  summary_out <- reactiveVal("default")
  
  # summarize patient history text with Vertex AI 
  summary_text <- eventReactive(input$get_summary, {
    patient_data <- p2yr_patient_history() 
    prompt_text <- paste(
      input$user_prompt, "\n",
      "Patient registration:\n", 
      patient_data$text_registration,"\n",
      "Patient history: ",  # no newline here seems to help LLM output
      patient_data$text_history,
      sep = "")
    
    # Send the response to the Vertex AI
    response <- gcva_text_gen_predict(
      projectId = project_id,
      locationId = region,
      prompt = prompt_text,
      modelId = "text-bison@001",
      temperature = input$temperature,
      maxOutputTokens = input$max_length,
      topP=input$top_p,
      topK=input$top_k
    )
    return(response)
  })
  
  # Monitor the 'get patient history' button and reset when new patient data fetched
  observeEvent(input$get_patient_history, {
    # set reactive value to determine ui to render
    summary_out("default")
    # Switch to the second tab when the button is pressed
    updateTabsetPanel(session, "tabs", selected = "tab2")
  })
  
  # Monitor the generate summary button
  observeEvent(input$get_summary, {
    # set reactive value to determine ui to render
    summary_out("generated")
    # Switch to the second tab when the button is pressed
    updateTabsetPanel(session, "tabs", selected = "tab1")
  })
  
  # output for patient summary
  output$summary <- renderUI({
    f$req_sign_in()
    tryCatch({
      switch(
        summary_out(), # lookup value
        "default" = HTML("No patient summary generated yet."),
        "generated" = HTML(markdown::markdownToHTML(summary_text(), fragment.only = TRUE))
      )
    },
    error = function(e) {
      HTML("No patient summary generated yet.")
    }
    )
  })
  
  # load response in background so user action completes without viewing tab
  outputOptions(output, "summary", suspendWhenHidden = FALSE)
  
  # search WebMD for primary reason for visit and display in tab
  webmd_search_ui <- eventReactive(input$get_patient_history, {
    input_search <- patients$primary_reason_of_visit[patients$name == input$patient_name]
    query <- gsub(" ", "+", input_search)
    tags$iframe(src = paste0("https://www.webmd.com/search/search_results/default.aspx?query=", query), 
                height = 600, width = "100%")
  })
  
  # render output based on user input
  output$iframe_webmd_search <- renderUI({
    tryCatch({
      webmd_search_ui()
      },
      error = function(e) {
        HTML("No WebMD search yet.")
    })
  })
  
  # load response in background so user action completes without viewing tab
  outputOptions(output, "iframe_webmd_search", suspendWhenHidden = FALSE)
  
  # listen for event to reset user prompt to default
  observeEvent(input$reset_user_prompt, {
    reset("user_prompt")
  })
  
  # listen for event to reset dev settings to default
  observeEvent(input$reset_dev_settings, {
    reset("dev-settings")
  })
  
  # listen for event to hide/secure elements after user sign out
  observeEvent(input$signout, {
    f$sign_out()
  })
  
}

## initialize  -------------------------------------------------------------
shinyApp(ui = ui, server = server)