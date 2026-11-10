package body Files.Grouping is

   use type Ada.Calendar.Time;
   use type Files.Types.Item_Kind;
   use type Files.Types.Color_Label;

   --  Each mode's bands in display order; a band number is 'Pos + 1.
   type Type_Band is (Folders, Images, Audio, Video, Documents, Archives, Other);
   type Modified_Band is (Today_Band, This_Week, Earlier, Unknown_Date);
   type Size_Band is (Empty, Small, Medium, Large, Unknown_Size);
   --  Red .. Gray (Real_Color_Label order), then unlabeled.
   Label_Band_Count : constant Positive := Files.Types.Color_Label'Pos (Files.Types.Color_Label'Last) + 1;

   Type_Keys : constant array (Type_Band) of access constant String :=
     [Folders   => new String'("details.group.folders"),
      Images    => new String'("details.group.images"),
      Audio     => new String'("details.group.audio"),
      Video     => new String'("details.group.video"),
      Documents => new String'("details.group.documents"),
      Archives  => new String'("details.group.archives"),
      Other     => new String'("details.group.other")];
   Modified_Keys : constant array (Modified_Band) of access constant String :=
     [Today_Band   => new String'("details.group.today"),
      This_Week    => new String'("details.group.this_week"),
      Earlier      => new String'("details.group.earlier"),
      Unknown_Date => new String'("details.group.unknown_date")];
   Size_Keys : constant array (Size_Band) of access constant String :=
     [Empty        => new String'("details.group.size_empty"),
      Small        => new String'("details.group.size_small"),
      Medium       => new String'("details.group.size_medium"),
      Large        => new String'("details.group.size_large"),
      Unknown_Size => new String'("details.group.size_unknown")];

   --  "This week": the six days before today.
   This_Week_Span : constant Duration := 6.0 * 86_400.0;
   Small_Size_Limit  : constant Long_Long_Integer := 1024 * 1024;
   Medium_Size_Limit : constant Long_Long_Integer := 1024 * 1024 * 1024;

   function Band_Count (Mode : Files.Types.Group_Mode) return Positive is
     (case Mode is
         when Files.Types.Group_By_Type     => Type_Band'Pos (Type_Band'Last) + 1,
         when Files.Types.Group_By_Modified => Modified_Band'Pos (Modified_Band'Last) + 1,
         when Files.Types.Group_By_Size     => Size_Band'Pos (Size_Band'Last) + 1,
         when Files.Types.Group_By_Label    => Label_Band_Count,
         when Files.Types.No_Grouping       => 1);

   function Day_Start (Value : Ada.Calendar.Time) return Ada.Calendar.Time is
      Year    : Ada.Calendar.Year_Number;
      Month   : Ada.Calendar.Month_Number;
      Day     : Ada.Calendar.Day_Number;
      Seconds : Ada.Calendar.Day_Duration;
   begin
      Ada.Calendar.Split (Value, Year, Month, Day, Seconds);
      return Ada.Calendar.Time_Of (Year, Month, Day);
   end Day_Start;

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
      return Positive
   is
      function Starts_With (Text : String; Prefix : String) return Boolean renames Files.Types.Starts_With;

      function Type_Of return Type_Band is
         Mime : constant String := Files.Types.To_Lower (Filetype);
      begin
         if Kind = Files.Types.Directory_Item then
            return Folders;
         elsif Starts_With (Mime, "image/") then
            return Images;
         elsif Starts_With (Mime, "audio/") then
            return Audio;
         elsif Starts_With (Mime, "video/") then
            return Video;
         elsif Starts_With (Mime, "text/")
           or else Mime = "application/pdf"
           or else Starts_With (Mime, "application/json")
           or else Starts_With (Mime, "application/xml")
           or else Starts_With (Mime, "application/vnd.")
         then
            return Documents;
         elsif Mime = "application/zip"
           or else Starts_With (Mime, "application/x-tar")
           or else Starts_With (Mime, "application/gzip")
           or else Starts_With (Mime, "application/x-7z")
           or else Starts_With (Mime, "application/x-rar")
         then
            return Archives;
         else
            return Other;
         end if;
      end Type_Of;

      function Modified_Of return Modified_Band is
      begin
         if not Modified_Available then
            return Unknown_Date;
         elsif Modified_Time >= Today then
            --  Today -- and a time past it (a skewed clock, a camera's), which
            --  is no older than now.
            return Today_Band;
         elsif Modified_Time > Today - This_Week_Span then
            return This_Week;
         else
            return Earlier;
         end if;
      end Modified_Of;

      function Size_Of return Size_Band is
      begin
         if not Size_Available then
            return Unknown_Size;
         elsif Size <= 0 then
            return Empty;
         elsif Size < Small_Size_Limit then
            return Small;
         elsif Size < Medium_Size_Limit then
            return Medium;
         else
            return Large;
         end if;
      end Size_Of;
   begin
      case Mode is
         when Files.Types.Group_By_Type =>
            return Type_Band'Pos (Type_Of) + 1;
         when Files.Types.Group_By_Modified =>
            return Modified_Band'Pos (Modified_Of) + 1;
         when Files.Types.Group_By_Size =>
            return Size_Band'Pos (Size_Of) + 1;
         when Files.Types.Group_By_Label =>
            return (if Label = Files.Types.No_Label then Label_Band_Count else Files.Types.Color_Label'Pos (Label));
         when Files.Types.No_Grouping =>
            return 1;
      end case;
   end Band_Of;

   function Band_Label_Key
     (Mode : Files.Types.Group_Mode;
      Band : Positive)
      return String
   is
      --  A band past the mode's last is its last (a stale number).
      function Clamped (Last : Natural) return Natural is (Natural'Min (Band - 1, Last));
   begin
      case Mode is
         when Files.Types.Group_By_Type =>
            return Type_Keys (Type_Band'Val (Clamped (Type_Band'Pos (Type_Band'Last)))).all;
         when Files.Types.Group_By_Modified =>
            return Modified_Keys (Modified_Band'Val (Clamped (Modified_Band'Pos (Modified_Band'Last)))).all;
         when Files.Types.Group_By_Size =>
            return Size_Keys (Size_Band'Val (Clamped (Size_Band'Pos (Size_Band'Last)))).all;
         when Files.Types.Group_By_Label =>
            return
              (if Band >= Label_Band_Count then "details.group.unlabeled"
               else "label.color." & Files.Types.To_Lower (Files.Types.Color_Label'Val (Band)'Image));
         when Files.Types.No_Grouping =>
            return "";
      end case;
   end Band_Label_Key;

end Files.Grouping;
