with Files.File_System;
with Ada.Containers.Hashed_Sets;
with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Strings;
with Ada.Numerics.Elementary_Functions;
with Ada.Strings.Hash;
with Ada.Strings.Unbounded;
with Ada.Strings.Unbounded.Hash;

with Guikit.Segmented;
with Guikit.Widgets;
with Files.Localization;
with Guikit.Utf8;
with Files.Rendering.Geometry;
with Files.Rendering.Labels;
with Files.Rendering.Layouts;

package body Files.Rendering is

   use Files.Rendering.Geometry;
   use Files.Rendering.Labels;
   use Files.Rendering.Layouts;
   use Ada.Strings.Unbounded;
   use type Ada.Containers.Count_Type;
   use type Ada.Calendar.Time;
   use type Files.Commands.Registered_Command_Id;
   use type Files.Types.Sort_Field;
   use type Files.Model.Tree_Pick_Mode;
   use type Files.Quick_Look.Content_Kind;
   use type Files.Types.Color_Label;
   use type Files.UI_Types.Focus_Target;
   use type Files.Types.Group_Mode;
   use type Files.Types.Item_Kind;
   use type Files.Types.View_Mode;

   --  Thumbnail pixels never contribute to Item_Snapshot equality (see the
   --  Thumbnail_Bitmap type in the spec).
   overriding function "=" (Left, Right : Thumbnail_Bitmap) return Boolean is
      pragma Unreferenced (Left, Right);
   begin
      return True;
   end "=";

   --  Parsed icon assets by their text: every icon drawn was parsed again on
   --  every frame rebuild. Keyed by the text itself, so a theme switch or
   --  another asset source (the tests install their own) never reuses a
   --  stale parse. A theme has a few dozen icons; the bound only guards
   --  against an unbounded source.
   package Parsed_Asset_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => Guikit.Draw.Icon_Asset,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=",
      "="             => Guikit.Draw."=");

   Parsed_Assets     : Parsed_Asset_Maps.Map;

   Max_Parsed_Assets : constant := 512;

   --  The icon Name of Theme, parsed.
   function Parsed_Icon_Asset (Name, Theme : String) return Guikit.Draw.Icon_Asset is
      Text     : constant String := Guikit.Draw.Icon_Asset_Text (Name, Theme);
      Position : constant Parsed_Asset_Maps.Cursor := Parsed_Assets.Find (Text);
   begin
      if Parsed_Asset_Maps.Has_Element (Position) then
         return Parsed_Asset_Maps.Element (Position);
      end if;
      declare
         Asset : constant Guikit.Draw.Icon_Asset := Guikit.Draw.Parse_Icon_Asset (Text);
      begin
         if Natural (Parsed_Assets.Length) >= Max_Parsed_Assets then
            Parsed_Assets.Clear;
         end if;
         Parsed_Assets.Insert (Text, Asset);
         return Asset;
      end;
   end Parsed_Icon_Asset;

   procedure Build_Snapshot_Into
     (Snapshot  : in out View_Snapshot;
      Model     : Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Now       : Ada.Calendar.Time;
      Keep_Rows : Boolean := False)
   is separate;

   function Build_Snapshot
     (Model    : Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return View_Snapshot
   is
   begin
      return Result : View_Snapshot do
         Build_Snapshot_Into (Result, Model, Settings, Ada.Calendar.Clock);
      end return;
   end Build_Snapshot;

   function Build_Frame_Commands
     (Snapshot    : View_Snapshot;
      Build       : Natural;
      Row_Texts   : in out Row_Text_Cache;
      Width       : Natural;
      Height      : Natural;
      Line_Height : Positive;
      Pointer     : Pointer_State := No_Pointer)
      return Frame_Commands
   is separate;

   function Build_Frame_Commands
     (Snapshot    : View_Snapshot;
      Width       : Natural;
      Height      : Natural;
      Line_Height : Positive;
      Pointer     : Pointer_State := No_Pointer)
      return Frame_Commands
   is
      --  A one-off frame: nothing formatted is kept.
      Row_Texts : Row_Text_Cache;
   begin
      return Build_Frame_Commands (Snapshot, 0, Row_Texts, Width, Height, Line_Height, Pointer);
   end Build_Frame_Commands;

   function Item_Now
     (Drawn : View_Snapshot;
      Index : Natural;
      Model : Files.Model.Window_Model)
      return Natural is
   begin
      if Index = 0 then
         return 0;
      end if;
      for Item of Drawn.Items loop
         if Item.Visible_Index = Index then
            return Files.Model.Visible_Index_Of (Model, To_String (Item.Full_Path));
         end if;
      end loop;
      return 0;
   end Item_Now;

end Files.Rendering;
