with Ada.Strings.Unbounded;
with Files.Background_Slots;
with Files.File_System;

package body Files.Extra_Info_Reader is
   use Ada.Strings.Unbounded;

   type Item_Facts is record
      Kind     : Files.Types.Item_Kind := Files.Types.Unknown_Item;
      Filetype : Unbounded_String;
   end record;

   function Read (Path : String; Facts : Item_Facts) return Unbounded_String is
     (To_Unbounded_String (Files.File_System.Extra_Info_Token (Path, Facts.Kind, To_String (Facts.Filetype))));

   --  Every answer, an empty one included, is handed out once: the model
   --  records it as loaded and does not ask again.
   function Always (Token : Unbounded_String) return Boolean is
      pragma Unreferenced (Token);
   begin
      return True;
   end Always;

   function No_Details return Unbounded_String is (Null_Unbounded_String);

   package Reader is new Files.Background_Slots
     (Parameters  => Item_Facts,
      Result      => Unbounded_String,
      Work        => Read,
      Failed      => No_Details,
      Handed_Once => Always);

   procedure Request
     (Owner    : Requester;
      Path     : String;
      Kind     : Files.Types.Item_Kind;
      Filetype : String) is
   begin
      Reader.Request (Reader.Requester (Owner), Path, (Kind => Kind, Filetype => To_Unbounded_String (Filetype)));
   end Request;

   procedure Take
     (Owner : Requester;
      Path  : String;
      Token : out Files.Types.UString;
      Ready : out Boolean;
      Asked : out Boolean) is
   begin
      Reader.Take (Reader.Requester (Owner), Path, Token, Ready, Asked);
   end Take;

end Files.Extra_Info_Reader;
