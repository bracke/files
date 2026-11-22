--  What the suite reaches of Files.Application that is not part of its interface.
package Files.Application.Testing is

   --  Parse application command-line arguments into runtime mode and paths.
   --
   --  Recognized flags are consumed before a -- terminator. Unknown options
   --  and missing settings values make the configuration invalid; a pathname
   --  beginning with a dash must follow --.
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
      Width  : Natural := Files.Rendering.Layouts.Default_Window_Width;
      Height : Natural := Files.Rendering.Layouts.Default_Window_Height;
      Locale : String := "en")
      return String;

end Files.Application.Testing;
