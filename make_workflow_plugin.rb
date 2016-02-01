PLUGIN_NAME = "test_plugin_dev"
WORKFLOW_NAME = "TestWorkflow"
WORKFLOW_ABBR = "tw"
TYPE_API_CODE = "std:type:file"
PANEL_NAME = "example_panel"


require "fileutils"


unless PLUGIN_NAME =~ /\A[a-z0-9_]+\z/ && PLUGIN_NAME.length > 8
  raise "Bad plugin name - must use a-z0-9_ only, and more than 8 characters."
end
if File.exist?(PLUGIN_NAME)
  raise "File or directory #{PLUGIN_NAME} already exists"
end
FileUtils.mkdir(PLUGIN_NAME)
['js', 'static', 'template', 'test'].each do |dir|
  FileUtils.mkdir("#{PLUGIN_NAME}/#{dir}")
end
random = java.security.SecureRandom.new()
rbytes = Java::byte[20].new
random.nextBytes(rbytes)
install_secret = String.from_java_bytes(rbytes).unpack('H*').join
plugin_url_fragment = PLUGIN_NAME.gsub('_','-')
File.open("#{PLUGIN_NAME}/plugin.json",'w') do |file|
  file.write(<<__E)
{
  "pluginName": "#{PLUGIN_NAME}",
  "pluginAuthor": "TODO Your Company",
  "pluginVersion": 1,
  "displayName": "#{PLUGIN_NAME.split('_').map {|e| e.capitalize} .join(' ')}",
  "displayDescription": "TODO Longer description of plugin",
  "installSecret": "#{install_secret}",
  "apiVersion": 4,
  "privilegesRequired": ["pDatabase"],
  "use": [
      "std:workflow",
      "std:reporting"
    ],
  "load": [
      "js/#{PLUGIN_NAME}.js",
      "js/#{WORKFLOW_ABBR}_workflow.js",
      "js/#{WORKFLOW_ABBR}_forms.js",
      "js/#{WORKFLOW_ABBR}_text.js",
      "js/#{WORKFLOW_ABBR}_reporting.js"
    ],
  "respond": ["/do/#{plugin_url_fragment}"]
}
__E
end
File.open("#{PLUGIN_NAME}/test/#{PLUGIN_NAME}_test1.js",'w') do |file|
  file.write(<<__E)

t.test(function() {

    // For documentation, see
    //   http://docs.haplo.org/dev/plugin/tests

    t.assert(true);

});

__E
end
File.open("#{PLUGIN_NAME}/requirements.schema",'w') do |file|
  file.write(<<__E)

type #{TYPE_API_CODE} as BASE_TYPE
    attribute dc:attribute:author
    element: std:group:everyone right std:action_panel {"panel": "#{PANEL_NAME}"}

# --------- Attributes ---------------------------------

attribute dc:attribute:author as Author

__E
end


File.open("#{PLUGIN_NAME}/js/#{WORKFLOW_ABBR}_workflow.js", "w") do |file|
  file.write(<<__E)
// Workflow documentation: http://docs.haplo.org/dev/standard-plugin/workflow
var #{WORKFLOW_NAME} = P.#{WORKFLOW_NAME} = P.workflow.implement("#{WORKFLOW_ABBR}", "Custom workflow").
    objectElementActionPanelName("#{PANEL_NAME}");

// Entities documentation: http://docs.haplo.org/dev/standard-plugin/workflow/definition/std-features/entities
#{WORKFLOW_NAME}.use("std:entities", {
    user: ["object", A.Author]
});
#{WORKFLOW_NAME}.use("std:entities:roles");

#{WORKFLOW_NAME}.start(function(M, initial, properties) {
    initial.state = "wait_submit";
});

#{WORKFLOW_NAME}.states({
    "wait_submit": {
        actionableBy: "user",
        transitions: [
            ["submit", "finished"]
        ]
    },
    "finished": {
        finish: true
    }
});
__E
end

File.open("#{PLUGIN_NAME}/js/#{WORKFLOW_ABBR}_forms.js", "w") do |file|
  file.write(<<__E)
// Forms documentation: http://docs.haplo.org/dev/plugin/form
var form = P.form({
    specificationVersion:0,
    formId: "exForm",
    formTitle: "Form",
    elements: [
        {
            type:"paragraph",
            path:"text",
            label:"Paragraph text field",
            required:true
        }
    ]
});

// Document store documentation: http://docs.haplo.org/dev/standard-plugin/document-store
P.#{WORKFLOW_NAME}.use("std:document_store", {
    name:"form",
    title: "Workflow form",
    path: "/do/#{plugin_url_fragment}/document-store",
    panel: 200,
    formsForKey: function(key) {
        return [form]; 
    },
    view: [{}],
    edit: [{roles:["user"], selector:{state:"wait_submit"}}]
});
__E
end

File.open("#{PLUGIN_NAME}/js/#{WORKFLOW_ABBR}_text.js", "w") do |file|
  file.write(<<__E)
// Workflow text documentation: http://docs.haplo.org/dev/standard-plugin/workflow/definition/text
P.#{WORKFLOW_NAME}.text({
    "workflow-process-name": "TODO workflow name",

    "status:wait_submit": "Waiting for sumbission",
    "status:finished": "Finished",

    "status-list:wait_submit": "Please submit",
    
    "action-label": "Progress",

    "transition:submit": "submit",
    "transition-indicator": "primary",

    "timeline-entry:START": "started the workflow",
    "timeline-entry:submit": "submitted"
});
__E
end

File.open("#{PLUGIN_NAME}/js/#{PLUGIN_NAME}.js", "w") do |file|
  file.write(<<__E)
// Action panel documentation: http://docs.haplo.org/dev/standard-plugin/action-panel
P.implementService("std:action_panel:#{PANEL_NAME}", function(display, builder) {
    var M = O.service("std:workflow:for_ref", "#{PLUGIN_NAME}:#{WORKFLOW_ABBR}", display.object.ref);
    if(M) { return; } // already started
    if(O.currentUser.ref == display.object.first(A.Author)) {
        builder.panel(100).link(100,
            "/do/#{plugin_url_fragment}/start/"+display.object.ref.toString(),
            "Workflow",
            "primary");
    }
});

// Request handling documentation: http://docs.haplo.org/dev/plugin/request-handling
P.respond("GET,POST", "/do/#{plugin_url_fragment}/start", [
    {pathElement:0, as:"object"}
], function(E, object) {
    if(E.request.method === "POST") {
        var M = P.#{WORKFLOW_NAME}.create({object:object});
        E.response.redirect("/do/#{plugin_url_fragment}/document-store/form/"+M.workUnit.id);
    }
    E.render({
        pageTitle: "Start workflow",
        backLink: object.url(),
        text: "Start workflow",
        options: [{label:"Start"}]
    }, "std:ui:confirm");
});
__E
end

File.open("#{PLUGIN_NAME}/js/#{WORKFLOW_ABBR}_reporting.js", "w") do |file|
  file.write(<<__E)

// TODO: This will not appear anywhere currently. Choose an appropriate location for the element to display
P.implementService("std:action_panel:TODO_PANEL_NAME", function(display, builder) {
    builder.panel(100).link(100,
        "/do/#{plugin_url_fragment}/states-dashboard/",
        "Workflow states",
        "default");
});

// Workflow dashboard documentation: http://docs.haplo.org/dev/standard-plugin/workflow/definition/std-features/states-dashboard
P.#{WORKFLOW_NAME}.use("std:dashboard:states", {
    title: "Workflow progress",
    path: "/do/#{plugin_url_fragment}/states-dashboard",
    canViewDashboard: function(dashboard, user) {
        return true;
    },
    states: [
        "wait_submit",
        "finished"
    ]
});
__E
end

