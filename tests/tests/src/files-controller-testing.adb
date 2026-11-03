package body Files.Controller.Testing is

   procedure Replace_Focused_Text
     (Model : in out Files.Model.Window_Model;
      Text  : String)
     renames Files.Controller.Replace_Focused_Text;

   function Save_Settings
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String)
      return Controller_Result
     renames Files.Controller.Save_Settings;

   function Toggle_Hidden_Files
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String)
      return Controller_Result
     renames Files.Controller.Toggle_Hidden_Files;

   function Toggle_Free_Space_Display
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String)
      return Controller_Result
     renames Files.Controller.Toggle_Free_Space_Display;

   function Handle_Scroll
     (Model : in out Files.Model.Window_Model;
      Lines : Integer)
      return Controller_Result
     renames Files.Controller.Handle_Scroll;

end Files.Controller.Testing;
