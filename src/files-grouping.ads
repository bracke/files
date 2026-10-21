with Ada.Calendar;
with Files.Types;

--  The Details view's grouping bands. The model keeps its items in band order
--  (then sort order within a band), so keyboard and range selection walk the
--  rows in the order they are drawn; the snapshot only draws a header where
--  the band changes.
package Files.Grouping is

   --  @param Mode Grouping mode.
   --  @return Number of bands Mode partitions items into.
   function Band_Count (Mode : Files.Types.Group_Mode) return Positive;

   --  The band an item belongs to under Mode, in drawing order.
   --
   --  @param Mode Grouping mode.
   --  @param Kind Item kind.
   --  @param Filetype MIME type text.
   --  @param Modified_Available Whether Modified_Time is known.
   --  @param Modified_Time Last modification time.
   --  @param Size_Available Whether Size is known.
   --  @param Size Size in bytes.
   --  @param Label The item's color label.
   --  @param Today Start of the current local day.
   --  @return Band number in 1 .. Band_Count (Mode); 1 for No_Grouping.
   function Band_Of
     (Mode               : Files.Types.Group_Mode;
      Kind               : Files.Types.Item_Kind;
      Filetype           : String;
      Modified_Available : Boolean;
      Modified_Time      : Ada.Calendar.Time;
      Size_Available     : Boolean;
      Size               : Long_Long_Integer;
      Label              : Files.Types.Color_Label;
      Today              : Ada.Calendar.Time)
      return Positive;

   --  @param Mode Grouping mode.
   --  @param Band Band number.
   --  @return Localization key of the band's header text.
   function Band_Label_Key
     (Mode : Files.Types.Group_Mode;
      Band : Positive)
      return String;

   --  @param Value A time.
   --  @return Midnight starting Value's local day.
   function Day_Start (Value : Ada.Calendar.Time) return Ada.Calendar.Time;

end Files.Grouping;
