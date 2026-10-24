package body Files.Grouping is

   use type Ada.Calendar.Time;
   use type Files.Types.Item_Kind;
   use type Files.Types.Color_Label;

   function Band_Count (Mode : Files.Types.Group_Mode) return Positive is
   begin
      case Mode is
         when Files.Types.Group_By_Type =>
            return 7;
         when Files.Types.Group_By_Modified =>
            return 4;
         when Files.Types.Group_By_Size =>
            return 5;
         when Files.Types.Group_By_Label =>
            return 8;
         when Files.Types.No_Grouping =>
            return 1;
      end case;
   end Band_Count;

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
      function Starts_With (Text : String; Prefix : String) return Boolean is
        (Text'Length >= Prefix'Length
         and then Text (Text'First .. Text'First + Prefix'Length - 1) = Prefix);

      function Type_Band return Positive is
         Mime : constant String := Files.Types.To_Lower (Filetype);
      begin
         if Kind = Files.Types.Directory_Item then
            return 1;
         elsif Starts_With (Mime, "image/") then
            return 2;
         elsif Starts_With (Mime, "audio/") then
            return 3;
         elsif Starts_With (Mime, "video/") then
            return 4;
         elsif Starts_With (Mime, "text/")
           or else Mime = "application/pdf"
           or else Starts_With (Mime, "application/json")
           or else Starts_With (Mime, "application/xml")
           or else Starts_With (Mime, "application/vnd.")
         then
            return 5;
         elsif Mime = "application/zip"
           or else Starts_With (Mime, "application/x-tar")
           or else Starts_With (Mime, "application/gzip")
           or else Starts_With (Mime, "application/x-7z")
           or else Starts_With (Mime, "application/x-rar")
         then
            return 6;
         else
            return 7;
         end if;
      end Type_Band;

      function Modified_Band return Positive is
      begin
         if not Modified_Available then
            return 4;
         elsif Modified_Time >= Today then
            --  Today -- and a time past it (a skewed clock, a camera's), which
            --  is no older than now.
            return 1;
         elsif Modified_Time > Today - 6.0 * 86_400.0 then
            return 2;
         else
            return 3;
         end if;
      end Modified_Band;

      function Size_Band return Positive is
      begin
         if not Size_Available then
            return 5;
         elsif Size <= 0 then
            return 1;
         elsif Size < 1024 * 1024 then
            return 2;
         elsif Size < 1024 * 1024 * 1024 then
            return 3;
         else
            return 4;
         end if;
      end Size_Band;
   begin
      case Mode is
         when Files.Types.Group_By_Type =>
            return Type_Band;
         when Files.Types.Group_By_Modified =>
            return Modified_Band;
         when Files.Types.Group_By_Size =>
            return Size_Band;
         when Files.Types.Group_By_Label =>
            --  Red .. Gray are bands 1 .. 7 (Real_Color_Label order), then
            --  unlabeled.
            return (if Label = Files.Types.No_Label then 8 else Files.Types.Color_Label'Pos (Label));
         when Files.Types.No_Grouping =>
            return 1;
      end case;
   end Band_Of;

   function Band_Label_Key
     (Mode : Files.Types.Group_Mode;
      Band : Positive)
      return String is
   begin
      case Mode is
         when Files.Types.Group_By_Type =>
            case Band is
               when 1 =>
                  return "details.group.folders";
               when 2 =>
                  return "details.group.images";
               when 3 =>
                  return "details.group.audio";
               when 4 =>
                  return "details.group.video";
               when 5 =>
                  return "details.group.documents";
               when 6 =>
                  return "details.group.archives";
               when others =>
                  return "details.group.other";
            end case;
         when Files.Types.Group_By_Modified =>
            case Band is
               when 1 =>
                  return "details.group.today";
               when 2 =>
                  return "details.group.this_week";
               when 3 =>
                  return "details.group.earlier";
               when others =>
                  return "details.group.unknown_date";
            end case;
         when Files.Types.Group_By_Size =>
            case Band is
               when 1 =>
                  return "details.group.size_empty";
               when 2 =>
                  return "details.group.size_small";
               when 3 =>
                  return "details.group.size_medium";
               when 4 =>
                  return "details.group.size_large";
               when others =>
                  return "details.group.size_unknown";
            end case;
         when Files.Types.Group_By_Label =>
            case Band is
               when 1 =>
                  return "label.color.red";
               when 2 =>
                  return "label.color.orange";
               when 3 =>
                  return "label.color.yellow";
               when 4 =>
                  return "label.color.green";
               when 5 =>
                  return "label.color.blue";
               when 6 =>
                  return "label.color.purple";
               when 7 =>
                  return "label.color.gray";
               when others =>
                  return "details.group.unlabeled";
            end case;
         when Files.Types.No_Grouping =>
            return "";
      end case;
   end Band_Label_Key;

end Files.Grouping;
