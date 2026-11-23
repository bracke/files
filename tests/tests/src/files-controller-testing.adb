with Files.Events;
package body Files.Controller.Testing is

   procedure Replace_Focused_Text
     (Model : in out Files.Model.Window_Model;
      Text  : String)
     renames Files.Controller.Replace_Focused_Text;

   procedure Note_Recent_Opens
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String;
      Accepted      : out Boolean)
     renames Files.Controller.Note_Recent_Opens;

   function Commit_Settings
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Updated       : Files.Settings.Settings_Model;
      Settings_Path : String)
      return Files.Settings.Settings_Write_Result
     renames Files.Controller.Commit_Settings;

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

   function Handle_Key
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Key       : Guikit.Input.Key_Code;
      Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Tree_Page_Rows : Natural := 0)
      return Controller_Result is
     (Files.Controller.Handle_Key
        (Model, Settings, Key, Files.Events.Translate_Key (Key, Modifiers), Modifiers, Tree_Page_Rows));

   function Handle_Drop_Import
     (Model        : in out Files.Model.Window_Model;
      Settings     : Files.Settings.Settings_Model;
      Source_Paths : Files.Types.String_Vectors.Vector;
      Mode         : Files.File_System_Types.Drop_Import_Mode := Files.File_System_Types.Drop_Copy)
      return Controller_Result
     renames Files.Controller.Handle_Drop_Import;

   function Accepts_Drop_Import (Model : Files.Model.Window_Model) return Boolean
     renames Files.Controller.Accepts_Drop_Import;

   function Activate_Palette_Command
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers)
      return Controller_Result renames Files.Controller.Activate_Palette_Command;

end Files.Controller.Testing;
