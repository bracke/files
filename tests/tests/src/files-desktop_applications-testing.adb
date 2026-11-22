package body Files.Desktop_Applications.Testing is

   function Build_Open_Action
     (App     : Application;
      Targets : Files.Types.String_Vectors.Vector)
      return Files.Settings.Open_Action renames Files.Desktop_Applications.Build_Open_Action;

   function Build_Open_Actions
     (App     : Application;
      Targets : Files.Types.String_Vectors.Vector)
      return Open_Action_Vectors.Vector renames Files.Desktop_Applications.Build_Open_Actions;

   function In_Terminal
     (Action   : Files.Settings.Open_Action;
      Terminal : String)
      return Files.Settings.Open_Action renames Files.Desktop_Applications.In_Terminal;

   function Desktop_Entry_Locale (Tag : String) return String renames Files.Desktop_Applications.Desktop_Entry_Locale;

end Files.Desktop_Applications.Testing;
