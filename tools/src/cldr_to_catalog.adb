with Ada.Command_Line;
with Ada.Containers.Vectors;
with Ada.Directories;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Text_IO;

with Project_Tools.Files;
with Project_Tools.Text;
use Project_Tools.Text;

procedure Cldr_To_Catalog is
   use Ada.Strings.Unbounded;

   type Catalog_Entry is record
      Key   : Unbounded_String;
      Value : Unbounded_String;
   end record;

   package Entry_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Catalog_Entry);

   function Attribute_Value
     (Tag  : String;
      Name : String)
      return String
   is
      Marker : constant String := Name & "=""";
      First  : constant Natural := Ada.Strings.Fixed.Index (Tag, Marker);
   begin
      if First = 0 then
         return "";
      end if;

      declare
         Start : constant Positive := First + Marker'Length;
         Stop  : constant Natural := Index_From (Tag, """", Start);
      begin
         if Stop = 0 then
            return "";
         end if;

         return Tag (Start .. Stop - 1);
      end;
   end Attribute_Value;

   function First_Tag
     (Text     : String;
      Tag_Name : String)
      return String
   is
      Pos : constant Natural := Ada.Strings.Fixed.Index (Text, "<" & Tag_Name);
   begin
      if Pos = 0 then
         return "";
      end if;

      declare
         Close : constant Natural := Index_From (Text, ">", Pos);
      begin
         if Close = 0 then
            return "";
         end if;

         return Text (Pos .. Close);
      end;
   end First_Tag;

   function Tag_With_Type
     (Text      : String;
      Tag_Name  : String;
      Type_Name : String)
      return String
   is
      Open : constant String := "<" & Tag_Name;
      Pos  : Natural := Ada.Strings.Fixed.Index (Text, Open);
   begin
      while Pos /= 0 loop
         declare
            Close : constant Natural := Index_From (Text, ">", Pos);
         begin
            if Close = 0 then
               return "";
            end if;

            declare
               Tag : constant String := Text (Pos .. Close);
            begin
               if Type_Name = "" or else Attribute_Value (Tag, "type") = Type_Name then
                  return Tag;
               end if;
            end;

            Pos := Index_From (Text, Open, Close + 1);
         end;
      end loop;

      return "";
   end Tag_With_Type;

   function Element_Text
     (Text      : String;
      Tag_Name  : String;
      Type_Name : String)
      return String
   is
      Open : constant String := "<" & Tag_Name;
      Pos  : Natural := Ada.Strings.Fixed.Index (Text, Open);
   begin
      while Pos /= 0 loop
         declare
            Close : constant Natural := Index_From (Text, ">", Pos);
         begin
            if Close = 0 then
               return "";
            end if;

            declare
               Tag : constant String := Text (Pos .. Close);
            begin
               if Type_Name = "" or else Attribute_Value (Tag, "type") = Type_Name then
                  declare
                     End_Tag : constant String := "</" & Tag_Name & ">";
                     Stop    : constant Natural := Index_From (Text, End_Tag, Close + 1);
                  begin
                     if Stop /= 0 then
                        return Ada.Strings.Fixed.Trim
                          (Text (Close + 1 .. Stop - 1), Ada.Strings.Both);
                     end if;
                  end;
               end if;
            end;

            Pos := Index_From (Text, Open, Close + 1);
         end;
      end loop;

      return "";
   end Element_Text;

   function Element_Text_With_Attribute
     (Text            : String;
      Tag_Name        : String;
      Attribute_Name  : String;
      Expected_Value  : String)
      return String
   is
      Open : constant String := "<" & Tag_Name;
      Pos  : Natural := Ada.Strings.Fixed.Index (Text, Open);
   begin
      while Pos /= 0 loop
         declare
            Close : constant Natural := Index_From (Text, ">", Pos);
         begin
            if Close = 0 then
               return "";
            end if;

            declare
               Tag : constant String := Text (Pos .. Close);
            begin
               if Expected_Value = ""
                 or else Attribute_Value (Tag, Attribute_Name) = Expected_Value
               then
                  declare
                     End_Tag : constant String := "</" & Tag_Name & ">";
                     Stop    : constant Natural := Index_From (Text, End_Tag, Close + 1);
                  begin
                     if Stop /= 0 then
                        return Ada.Strings.Fixed.Trim
                          (Text (Close + 1 .. Stop - 1), Ada.Strings.Both);
                     end if;
                  end;
               end if;
            end;

            Pos := Index_From (Text, Open, Close + 1);
         end;
      end loop;

      return "";
   end Element_Text_With_Attribute;

   function Section
     (Text       : String;
      Open_Text  : String;
      Close_Text : String)
      return String
   is
      First : constant Natural := Ada.Strings.Fixed.Index (Text, Open_Text);
   begin
      if First = 0 then
         return "";
      end if;

      declare
         Start : constant Natural := Index_From (Text, ">", First);
      begin
         if Start = 0 then
            return "";
         end if;

         declare
            Stop : constant Natural := Index_From (Text, Close_Text, Start + 1);
         begin
            if Stop = 0 then
               return "";
            end if;

            return Text (Start + 1 .. Stop - 1);
         end;
      end;
   end Section;

   function Locale_Name (Content : String) return String is
      Identity  : constant String := Section (Content, "<identity", "</identity>");
      Language  : constant String := Attribute_Value (First_Tag (Identity, "language"), "type");
      Territory : constant String := Attribute_Value (First_Tag (Identity, "territory"), "type");
      Script    : constant String := Attribute_Value (First_Tag (Identity, "script"), "type");
   begin
      if Language = "" then
         return "";
      elsif Territory /= "" then
         return Language & "-" & Territory;
      elsif Script /= "" then
         return Language & "-" & Script;
      end if;

      return Language;
   end Locale_Name;

   procedure Add
     (Entries : in out Entry_Vectors.Vector;
      Locale  : String;
      Key     : String;
      Value   : String) is
   begin
      if Value /= "" then
         Entries.Append
           (Catalog_Entry'
              (Key   => To_Unbounded_String (Locale & "." & Key),
               Value => To_Unbounded_String (Value)));
      end if;
   end Add;

   function Gregorian_Calendar (Content : String) return String is
      Calendars : constant String := Section (Content, "<calendars", "</calendars>");
   begin
      return Section (Calendars, "<calendar type=""gregorian""", "</calendar>");
   end Gregorian_Calendar;

   function Number_Symbol
     (Content : String;
      Name    : String)
      return String
   is
      Numbers : constant String := Section (Content, "<numbers", "</numbers>");
      Symbols : constant String := Section (Numbers, "<symbols numberSystem=""latn""", "</symbols>");
   begin
      return Element_Text (Symbols, Name, "");
   end Number_Symbol;

   function Digital_Unit_Label
     (Content   : String;
      Unit_Name : String)
      return String
   is
      Units       : constant String := Section (Content, "<units", "</units>");
      Short_Units : constant String := Section (Units, "<unitLength type=""short""", "</unitLength>");
      Unit        : constant String := Section (Short_Units, "<unit type=""" & Unit_Name & """", "</unit>");
      Pattern     : constant String := Element_Text_With_Attribute (Unit, "unitPattern", "count", "other");
      Display     : constant String := Element_Text (Unit, "displayName", "");

      function Strip_Number_Prefix (Value : String) return String is
         Start : Natural := Value'First + 3;
      begin
         while Start <= Value'Last loop
            if Value (Start) = ' ' then
               Start := Start + 1;
            elsif Start < Value'Last
              and then Character'Pos (Value (Start)) = 16#C2#
              and then Character'Pos (Value (Start + 1)) = 16#A0#
            then
               Start := Start + 2;
            else
               exit;
            end if;
         end loop;

         if Start > Value'Last then
            return "";
         end if;

         return Value (Start .. Value'Last);
      end Strip_Number_Prefix;
   begin
      if Pattern'Length > 3 and then Starts_With (Pattern, "{0}") then
         return Strip_Number_Prefix (Pattern);
      elsif Pattern = "{0}" then
         return "";
      elsif Display /= "" then
         return Display;
      end if;

      return "";
   end Digital_Unit_Label;

   function Month_Name
     (Calendar : String;
      Width    : String;
      Number   : Positive)
      return String
   is
      Months  : constant String := Section (Calendar, "<months", "</months>");
      Context : constant String := Section (Months, "<monthContext type=""format""", "</monthContext>");
      Names   : constant String := Section (Context, "<monthWidth type=""" & Width & """", "</monthWidth>");
   begin
      return Element_Text (Names, "month", Ada.Strings.Fixed.Trim (Positive'Image (Number), Ada.Strings.Both));
   end Month_Name;

   function Day_Name
     (Calendar : String;
      Width    : String;
      Day      : String)
      return String
   is
      Days    : constant String := Section (Calendar, "<days", "</days>");
      Context : constant String := Section (Days, "<dayContext type=""format""", "</dayContext>");
      Names   : constant String := Section (Context, "<dayWidth type=""" & Width & """", "</dayWidth>");
   begin
      return Element_Text (Names, "day", Day);
   end Day_Name;

   function Pattern
     (Calendar : String;
      Group    : String;
      Length   : String)
      return String
   is
      Formats     : constant String := Section (Calendar, "<" & Group, "</" & Group & ">");
      Length_Node : constant String :=
        Section (Formats, "<" & Group (Group'First .. Group'Last - 1) & "Length type=""" & Length & """", "</"
                 & Group (Group'First .. Group'Last - 1) & "Length>");
   begin
      return Element_Text (Length_Node, "pattern", "");
   end Pattern;

   function Date_Time_Pattern (Calendar : String) return String is
      Formats     : constant String := Section (Calendar, "<dateTimeFormats", "</dateTimeFormats>");
      Length_Node : constant String :=
        Section (Formats, "<dateTimeFormatLength type=""medium""", "</dateTimeFormatLength>");
   begin
      return Element_Text (Length_Node, "pattern", "");
   end Date_Time_Pattern;

   function Relative_Day
     (Calendar : String;
      Offset   : String)
      return String
   is
      Fields : constant String := Section (Calendar, "<fields", "</fields>");
      Day    : constant String := Section (Fields, "<field type=""day""", "</field>");
   begin
      return Element_Text (Day, "relative", Offset);
   end Relative_Day;

   function Convert_Pattern (Pattern_Text : String) return String is
      Result : Unbounded_String;
      Index  : Positive := Pattern_Text'First;

      procedure Append_Run
        (Symbol : Character;
         Count  : Natural) is
      begin
         case Symbol is
            when 'E' =>
               if Count >= 4 then
                  Append (Result, "%A");
               else
                  Append (Result, "%a");
               end if;
            when 'M' | 'L' =>
               if Count >= 4 then
                  Append (Result, "%B");
               elsif Count = 3 then
                  Append (Result, "%b");
               else
                  Append (Result, "%m");
               end if;
            when 'd' =>
               Append (Result, "%d");
            when 'y' | 'Y' =>
               if Count = 2 then
                  Append (Result, "%y");
               else
                  Append (Result, "%Y");
               end if;
            when 'H' =>
               Append (Result, "%H");
            when 'h' =>
               Append (Result, "%I");
            when 'm' =>
               Append (Result, "%M");
            when 's' =>
               Append (Result, "%S");
            when 'a' =>
               Append (Result, "%p");
            when 'z' | 'Z' =>
               Append (Result, "%Z");
            when others =>
               for Repeat in 1 .. Count loop
                  Append (Result, Symbol);
               end loop;
         end case;
      end Append_Run;
   begin
      while Index <= Pattern_Text'Last loop
         if Pattern_Text (Index) = ''' then
            Index := Index + 1;
            while Index <= Pattern_Text'Last and then Pattern_Text (Index) /= ''' loop
               Append (Result, Pattern_Text (Index));
               Index := Index + 1;
            end loop;
            Index := Index + 1;
         elsif Pattern_Text (Index) in 'A' .. 'Z' or else Pattern_Text (Index) in 'a' .. 'z' then
            declare
               Symbol : constant Character := Pattern_Text (Index);
               Start  : constant Positive := Index;
            begin
               while Index <= Pattern_Text'Last and then Pattern_Text (Index) = Symbol loop
                  Index := Index + 1;
               end loop;
               Append_Run (Symbol, Index - Start);
            end;
         else
            Append (Result, Pattern_Text (Index));
            Index := Index + 1;
         end if;
      end loop;

      return To_String (Result);
   end Convert_Pattern;

   function Combined_Date_Time
     (Date_Time : String;
      Date_Text : String;
      Time_Text : String)
      return String
   is
      function Replace_Once
        (Text        : String;
         Placeholder : String;
         Value       : String)
         return String
      is
         Pos : constant Natural := Ada.Strings.Fixed.Index (Text, Placeholder);
      begin
         if Pos = 0 then
            return Text;
         end if;

         declare
            Prefix : constant String :=
              (if Pos = Text'First then "" else Text (Text'First .. Pos - 1));
            Suffix_Start : constant Natural := Pos + Placeholder'Length;
            Suffix : constant String :=
              (if Suffix_Start > Text'Last then "" else Text (Suffix_Start .. Text'Last));
         begin
            return Prefix & Value & Suffix;
         end;
      end Replace_Once;
   begin
      if Date_Time = "" then
         return Date_Text & " " & Time_Text;
      end if;

      declare
         With_Time : constant String := Replace_Once (Date_Time, "{0}", Time_Text);
      begin
         if With_Time = Date_Time then
            return Date_Text & " " & Time_Text;
         end if;

         declare
            With_Date : constant String := Replace_Once (With_Time, "{1}", Date_Text);
         begin
            if With_Date = With_Time then
               return Date_Text & " " & Time_Text;
            end if;

            return With_Date;
         end;
      end;
   end Combined_Date_Time;

   procedure Import_File
     (Path    : String;
      Entries : in out Entry_Vectors.Vector)
   is
      Content  : constant String := Project_Tools.Files.Read_Raw_File (Path);
      Locale   : constant String := Locale_Name (Content);
      Calendar : constant String := Gregorian_Calendar (Content);
      Date_Med : constant String := Convert_Pattern (Pattern (Calendar, "dateFormats", "medium"));
      Time_Med : constant String := Convert_Pattern (Pattern (Calendar, "timeFormats", "medium"));
      DateTime : constant String := Date_Time_Pattern (Calendar);
      Day_Map  : constant array (Natural range 0 .. 6) of String (1 .. 3) :=
        ["mon", "tue", "wed", "thu", "fri", "sat", "sun"];

      function Day_Key (Day : Natural) return String is
      begin
         case Day is
            when 0 =>
               return "monday";
            when 1 =>
               return "tuesday";
            when 2 =>
               return "wednesday";
            when 3 =>
               return "thursday";
            when 4 =>
               return "friday";
            when 5 =>
               return "saturday";
            when others =>
               return "sunday";
         end case;
      end Day_Key;
   begin
      if Locale = "" or else Calendar = "" then
         return;
      end if;

      Add (Entries, Locale, "number.decimal", Number_Symbol (Content, "decimal"));
      Add (Entries, Locale, "number.group", Number_Symbol (Content, "group"));

      Add (Entries, Locale, "details.size.unit.bytes", Digital_Unit_Label (Content, "digital-byte"));
      Add (Entries, Locale, "details.size.unit.kib", Digital_Unit_Label (Content, "digital-kilobyte"));
      Add (Entries, Locale, "details.size.unit.mib", Digital_Unit_Label (Content, "digital-megabyte"));
      Add (Entries, Locale, "details.size.unit.gib", Digital_Unit_Label (Content, "digital-gigabyte"));
      Add (Entries, Locale, "details.size.unit.tib", Digital_Unit_Label (Content, "digital-terabyte"));
      Add (Entries, Locale, "details.size.unit.pib", Digital_Unit_Label (Content, "digital-petabyte"));

      Add (Entries, Locale, "time.format.clock", "%H:%M:%S");

      if Date_Med /= "" and then Time_Med /= "" then
         Add (Entries, Locale, "time.format.full", Combined_Date_Time (DateTime, Date_Med, Time_Med));
         Add (Entries, Locale, "time.locale.datetime_pattern", Combined_Date_Time (DateTime, Date_Med, Time_Med));
      end if;

      Add (Entries, Locale, "time.locale.date_pattern", Date_Med);
      Add (Entries, Locale, "time.locale.time_pattern", Time_Med);
      Add (Entries, Locale, "time.locale.am", Element_Text (Calendar, "dayPeriod", "am"));
      Add (Entries, Locale, "time.locale.pm", Element_Text (Calendar, "dayPeriod", "pm"));
      Add (Entries, Locale, "time.relative.now", Relative_Day (Calendar, "0"));
      Add (Entries, Locale, "time.relative.today", Relative_Day (Calendar, "0"));
      Add (Entries, Locale, "time.relative.yesterday", Relative_Day (Calendar, "-1"));

      for Month in 1 .. 12 loop
         declare
            Image : constant String := Ada.Strings.Fixed.Trim (Positive'Image (Month), Ada.Strings.Both);
         begin
            Add (Entries, Locale, "time.month" & Image & ".short", Month_Name (Calendar, "abbreviated", Month));
            Add (Entries, Locale, "time.month" & Image & ".long", Month_Name (Calendar, "wide", Month));
         end;
      end loop;

      for Day in Day_Map'Range loop
         declare
            Image : constant String := Ada.Strings.Fixed.Trim (Natural'Image (Day), Ada.Strings.Both);
         begin
            Add (Entries, Locale, "time.day" & Image & ".short", Day_Name (Calendar, "abbreviated", Day_Map (Day)));
            Add (Entries, Locale, "time.day" & Image & ".long", Day_Name (Calendar, "wide", Day_Map (Day)));
            Add (Entries, Locale, "time.weekday." & Day_Key (Day), Day_Name (Calendar, "wide", Day_Map (Day)));
         end;
      end loop;
   end Import_File;

   procedure Import_Path
     (Path    : String;
      Entries : in out Entry_Vectors.Vector);

   procedure Import_Path
     (Path    : String;
      Entries : in out Entry_Vectors.Vector)
   is
      Search  : Ada.Directories.Search_Type;
      Element : Ada.Directories.Directory_Entry_Type;
      Started : Boolean := False;
   begin
      if Project_Tools.Files.File_Exists (Path) then
         if Ends_With (Path, ".xml") then
            Import_File (Path, Entries);
         end if;
         return;
      elsif not Project_Tools.Files.Directory_Exists (Path) then
         return;
      end if;

      Ada.Directories.Start_Search
        (Search,
         Directory => Path,
         Pattern   => "*",
         Filter    =>
           [Ada.Directories.Ordinary_File => True,
            Ada.Directories.Directory     => True,
            Ada.Directories.Special_File  => False]);
      Started := True;

      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Element);
         declare
            Name : constant String := Ada.Directories.Simple_Name (Element);
            Full : constant String := Ada.Directories.Full_Name (Element);
         begin
            if Name /= "." and then Name /= ".." then
               Import_Path (Full, Entries);
            end if;
         end;
      end loop;

      Ada.Directories.End_Search (Search);
   exception
      when others =>
         if Started then
            Ada.Directories.End_Search (Search);
         end if;
         raise;
   end Import_Path;

   function Render (Entries : Entry_Vectors.Vector) return String is
      Result : Unbounded_String;
   begin
      for Item of Entries loop
         Append (Result, To_String (Item.Key));
         Append (Result, " = ");
         Append (Result, To_String (Item.Value));
         Append (Result, ASCII.LF);
      end loop;

      return To_String (Result);
   end Render;

   Entries : Entry_Vectors.Vector;
begin
   if Ada.Command_Line.Argument_Count not in 1 .. 2
     or else Ada.Command_Line.Argument (1) = "--help"
   then
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "Usage: cldr_to_catalog CLDR_XML_PATH [OUTPUT_CATALOG_FRAGMENT]");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;

   Import_Path (Ada.Command_Line.Argument (1), Entries);

   if Entries.Is_Empty then
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "No CLDR LDML locale entries were imported.");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;

   if Ada.Command_Line.Argument_Count = 2 then
      Project_Tools.Files.Write_Raw_File (Ada.Command_Line.Argument (2), Render (Entries));
   else
      Ada.Text_IO.Put (Render (Entries));
   end if;
end Cldr_To_Catalog;
