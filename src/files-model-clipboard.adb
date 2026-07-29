separate (Files.Model)
package body Clipboard is
   use Ada.Strings.Unbounded;

   procedure Set_System_Clipboard_Request
     (Model : in out Window_Model;
      Text  : String) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.System_Clipboard_Request_Value := To_Unbounded_String (Text);
      Model.System_Clipboard_Request_Pending := True;
   end Set_System_Clipboard_Request;

   function System_Clipboard_Request_Pending
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.System_Clipboard_Request_Pending;
   end System_Clipboard_Request_Pending;

   function System_Clipboard_Request_Text
     (Model : Window_Model)
      return String is
   begin
      return To_String (Model.System_Clipboard_Request_Value);
   end System_Clipboard_Request_Text;

   procedure Clear_System_Clipboard_Request
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.System_Clipboard_Request_Value := Null_Unbounded_String;
      Model.System_Clipboard_Request_Pending := False;
   end Clear_System_Clipboard_Request;

   procedure Set_Clipboard
     (Model : in out Window_Model;
      Paths : Files.Types.String_Vectors.Vector;
      Mode  : Clipboard_Mode) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Clipboard_Paths_Value := Paths;
      Model.Clipboard_Mode_Value :=
        (if Paths.Is_Empty then Clipboard_None else Mode);
   end Set_Clipboard;

   procedure Clear_Clipboard
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Clipboard_Paths_Value.Clear;
      Model.Clipboard_Mode_Value := Clipboard_None;
   end Clear_Clipboard;

   function Clipboard_Paths
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector is
   begin
      return Model.Clipboard_Paths_Value;
   end Clipboard_Paths;

   function Clipboard_Mode_Of
     (Model : Window_Model)
      return Clipboard_Mode is
   begin
      return Model.Clipboard_Mode_Value;
   end Clipboard_Mode_Of;

   function Clipboard_Has_Items
     (Model : Window_Model)
      return Boolean is
   begin
      return not Model.Clipboard_Paths_Value.Is_Empty
        and then Model.Clipboard_Mode_Value /= Clipboard_None;
   end Clipboard_Has_Items;

end Clipboard;
