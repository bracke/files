with Ada.Calendar;
with Ada.Strings.Unbounded;
with Files.Background_Slots;
with Files.File_System;
with Files.Types;

package body Files.Extra_Info_Reader is
   use Ada.Strings.Unbounded;

   --  What the details depend on besides the path: the item's revision (as
   --  listed) and the window's hidden-files setting.
   type Item_Facts is record
      Kind               : Files.Types.Item_Kind := Files.Types.Unknown_Item;
      Filetype           : Unbounded_String;
      Modified_Available : Boolean := False;
      Modified_Time      : Ada.Calendar.Time := Files.Types.Unknown_Time;
      Size_Available     : Boolean := False;
      Size               : Long_Long_Integer := 0;
      Show_Hidden        : Boolean := False;
   end record;

   function Facts_Of
     (Item        : Files.Items.Directory_Item;
      Show_Hidden : Boolean)
      return Item_Facts is
     ((Kind               => Item.Kind,
       Filetype           => Item.Filetype,
       Modified_Available => Item.Modified_Available,
       Modified_Time      => Item.Modified_Time,
       Size_Available     => Item.Size_Available,
       Size               => Item.Size,
       Show_Hidden        => Show_Hidden));

   function Read (Path : String; Facts : Item_Facts) return Files.Extra_Info.Info is
     (Files.File_System.Extra_Info_Of (Path, Facts.Kind, To_String (Facts.Filetype), Facts.Show_Hidden));

   --  Every answer, an empty one included, is handed out once: the model
   --  records it as loaded and does not ask again.
   function Always (Extra : Files.Extra_Info.Info) return Boolean is
      pragma Unreferenced (Extra);
   begin
      return True;
   end Always;

   function No_Details return Files.Extra_Info.Info is (Files.Extra_Info.No_Info);

   package Reader is new Files.Background_Slots
     (Parameters  => Item_Facts,
      Result      => Files.Extra_Info.Info,
      Work        => Read,
      Failed      => No_Details,
      Handed_Once => Always);

   procedure Request
     (Owner       : Requester;
      Item        : Files.Items.Directory_Item;
      Show_Hidden : Boolean) is
   begin
      Reader.Request (Reader.Requester (Owner), To_String (Item.Full_Path), Facts_Of (Item, Show_Hidden));
   end Request;

   procedure Take
     (Owner       : Requester;
      Item        : Files.Items.Directory_Item;
      Show_Hidden : Boolean;
      Extra       : out Files.Extra_Info.Info;
      Ready       : out Boolean;
      Asked       : out Boolean) is
   begin
      Reader.Take
        (Reader.Requester (Owner), To_String (Item.Full_Path), Facts_Of (Item, Show_Hidden), Extra, Ready, Asked);
   end Take;

   procedure Release (Owner : Requester) is
   begin
      Reader.Release (Reader.Requester (Owner));
   end Release;

end Files.Extra_Info_Reader;
