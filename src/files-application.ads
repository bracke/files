with Ada.Containers.Vectors;

with Files.Model;
with Files.Settings;
with Files.Types;

--  Application startup, command-line path resolution, and window model creation.
package Files.Application is
   subtype UString is Files.Types.UString;
   package String_Vectors renames Files.Types.String_Vectors;

   type Startup_Window is record
      Path  : UString;
      Title : UString;
      Model : Files.Model.Window_Model;
   end record;

   package Window_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Startup_Window);

   type Startup_Error is record
      Input_Path : UString;
      Error_Key  : UString;
   end record;

   package Error_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Startup_Error);

   type Startup_Result is record
      Windows : Window_Vectors.Vector;
      Errors  : Error_Vectors.Vector;
      Settings : Files.Settings.Settings_Model;
      Settings_Path : UString;
   end record;

   type Run_Mode is
     (Desktop_Run,
      Headless_Smoke_Run,
      Live_Smoke_Run,
      Version_Run,
      Help_Run);

   type Run_Configuration is record
      Mode  : Run_Mode := Desktop_Run;
      Paths : String_Vectors.Vector;
      Settings_Path : UString;
   end record;

   --  Parse application command-line arguments into runtime mode and paths.
   --
   --  Recognized smoke flags and settings-path selectors are consumed before
   --  a -- terminator. Unknown dash-prefixed values remain paths so normal
   --  startup path behavior is preserved.
   --
   --  @param Arguments Raw command-line arguments.
   --  @return Parsed runtime mode and path arguments.
   function Parse_Run_Configuration
     (Arguments : String_Vectors.Vector)
      return Run_Configuration;

   --  Return localized command-line help text for the files executable.
   --
   --  @param Locale Requested locale identifier.
   --  @return Newline-separated command-line help text.
   function Help_Text
     (Locale : String := "en")
      return String;

   --  Return command-line version text for the files executable.
   --
   --  @return Crate name and version from generated Alire configuration.
   function Version_Text return String;

   --  Return the current user's home directory using platform environment variables.
   --
   --  @return Home directory path, or the current directory as a fallback.
   function Home_Directory return String;

   --  Return the default settings file path under a home directory.
   --
   --  @param Home_Path Home directory path.
   --  @return Default settings file path.
   function Default_Settings_Path
     (Home_Path : String)
      return String;

   --  Return the settings file path selected by environment or default fallback.
   --
   --  FILES_SETTINGS overrides all defaults. XDG_CONFIG_HOME selects an XDG path
   --  when present. Otherwise the path is under Home_Path.
   --
   --  @param Home_Path Home directory path.
   --  @return Configured settings file path.
   function Configured_Settings_Path
     (Home_Path : String)
      return String;

   --  Load startup settings and resolve command-line paths into window models.
   --
   --  Invalid existing settings files are reported as startup errors and default
   --  settings are used to continue resolving requested windows.
   --
   --  @param Arguments Command-line arguments as paths.
   --  @param Settings_Path Explicit settings path, or empty to use configured path.
   --  @return Startup windows and recoverable startup errors.
   function Resolve_Startup
     (Arguments     : String_Vectors.Vector;
      Settings_Path : String := "")
      return Startup_Result;

   --  Resolve command-line paths into one window model per valid directory.
   --
   --  @param Arguments Command-line arguments as paths.
   --  @param Settings Settings used for loading and view defaults.
   --  @return Startup windows and recoverable startup errors.
   function Resolve_Startup_Paths
     (Arguments : String_Vectors.Vector;
      Settings  : Files.Settings.Settings_Model)
      return Startup_Result;

   --  Format startup windows and recoverable errors as localized status text.
   --
   --  @param Result Startup result to format.
   --  @param Locale Requested locale identifier.
   --  @return Newline-separated startup status text.
   function Startup_Report
     (Result : Startup_Result;
      Locale : String := "en")
      return String;

   --  Format a localized desktop startup error from a diagnostic key.
   --
   --  @param Error_Key Diagnostic key raised by the desktop window layer.
   --  @param Locale Requested locale identifier.
   --  @return Localized desktop startup error text.
   function Desktop_Error_Report
     (Error_Key : String;
      Locale    : String := "en")
      return String;

   --  Build a backend-neutral runtime smoke report for resolved windows.
   --
   --  This exercises snapshot construction, frame commands, text glyph
   --  generation, and Vulkan submission batching without opening native
   --  windows or touching the filesystem.
   --
   --  @param Result Startup result to smoke-test.
   --  @param Width Frame width in pixels.
   --  @param Height Frame height in pixels.
   --  @param Locale Requested locale identifier.
   --  @return Newline-separated smoke-test status text.
   function Runtime_Smoke_Report
     (Result : Startup_Result;
      Width  : Natural := 1024;
      Height : Natural := 768;
      Locale : String := "en")
      return String;

   --  Run the application entry point using process command-line arguments.
   --
   --  The selected run mode may print help, execute smoke checks, or open
   --  desktop windows after resolving startup paths and settings.
   procedure Run;

end Files.Application;
