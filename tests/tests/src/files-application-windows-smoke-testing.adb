package body Files.Application.Windows.Smoke.Testing is

   function Check_Window_Frame
     (Model    : Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Width    : Natural;
      Height   : Natural)
      return Window_Frame_Check
     renames Files.Application.Windows.Smoke.Check_Window_Frame;

end Files.Application.Windows.Smoke.Testing;
