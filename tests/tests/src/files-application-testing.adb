package body Files.Application.Testing is

   function Parse_Run_Configuration
     (Arguments : String_Vectors.Vector)
      return Run_Configuration renames Files.Application.Parse_Run_Configuration;

   function Help_Text
     (Locale : String := "en")
      return String renames Files.Application.Help_Text;

   function Version_Text return String renames Files.Application.Version_Text;

   function Resolve_Startup
     (Arguments     : String_Vectors.Vector;
      Settings_Path : String := "")
      return Startup_Result renames Files.Application.Resolve_Startup;

   function Resolve_Startup_Paths
     (Arguments : String_Vectors.Vector;
      Settings  : Files.Settings.Settings_Model)
      return Startup_Result renames Files.Application.Resolve_Startup_Paths;

   function Startup_Report
     (Result : Startup_Result;
      Locale : String := "en")
      return String renames Files.Application.Startup_Report;

   function Desktop_Error_Report
     (Error_Key : String;
      Locale    : String := "en")
      return String renames Files.Application.Desktop_Error_Report;

   function Runtime_Smoke_Report
     (Result : Startup_Result;
      Width  : Natural := Files.Rendering.Layouts.Default_Window_Width;
      Height : Natural := Files.Rendering.Layouts.Default_Window_Height;
      Locale : String := "en")
      return String renames Files.Application.Runtime_Smoke_Report;

   function Home_Directory return String renames Files.Application.Home_Directory;

end Files.Application.Testing;
