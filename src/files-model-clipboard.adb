with Files.Model.Support;

package body Files.Model.Clipboard is

   use Ada.Strings.Unbounded;
   use Files.Model.Support;

   procedure Set
     (Model : in out Window_Model;
      Paths : Files.Types.String_Vectors.Vector;
      Mode  : Clipboard_Mode) is
   begin
      Touch (Model);
      Model.Clipboard.Paths := Paths;
      Model.Clipboard.Mode :=
        (if Paths.Is_Empty then Clipboard_None else Mode);
   end Set;

   procedure Clear
     (Model : in out Window_Model) is
   begin
      Touch (Model);
      Model.Clipboard.Paths.Clear;
      Model.Clipboard.Mode := Clipboard_None;
   end Clear;

   function Paths
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector is
     (Model.Clipboard.Paths);

   function Mode_Of
     (Model : Window_Model)
      return Clipboard_Mode is
     (Model.Clipboard.Mode);

   function Has_Items
     (Model : Window_Model)
      return Boolean is
     (not Model.Clipboard.Paths.Is_Empty
       and then Model.Clipboard.Mode /= Clipboard_None);

   procedure Set_System_Request
     (Model : in out Window_Model;
      Text  : String) is
   begin
      Touch (Model);
      Model.Clipboard.System_Request := To_Unbounded_String (Text);
      Model.Clipboard.System_Request_Pending := True;
   end Set_System_Request;

   function System_Request_Pending
     (Model : Window_Model)
      return Boolean is
     (Model.Clipboard.System_Request_Pending);

   function System_Request_Text
     (Model : Window_Model)
      return String is
     (To_String (Model.Clipboard.System_Request));

   procedure Clear_System_Request
     (Model : in out Window_Model) is
   begin
      Touch (Model);
      Model.Clipboard.System_Request := Null_Unbounded_String;
      Model.Clipboard.System_Request_Pending := False;
   end Clear_System_Request;

end Files.Model.Clipboard;
