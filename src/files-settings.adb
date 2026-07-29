with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with GNAT.OS_Lib;

with Files.UTF8;

package body Files.Settings is
   use Ada.Strings.Unbounded;
   use type Ada.Directories.File_Kind;

   function Snapshot_Settings_Key_Of
     (Settings : Settings_Model)
      return Snapshot_Settings_Key is
   begin
      return
        (Show_File_Extensions => Settings.Show_File_Extensions,
         Show_Used_Space      => Settings.Show_Used_Space,
         Show_Space_Bar       => Settings.Show_Space_Bar,
         Theme                => Settings.Theme,
         Icon_Theme_Name      => Settings.Icon_Theme_Name,
         Column_Visible       => Settings.Column_Visible,
         Column_Widths        => Settings.Column_Widths,
         Column_Order         => Settings.Column_Order,
         Group_By             => Settings.Group_By,
         Favorite_Paths       => Settings.Favorite_Paths,
         Labels               => Settings.Labels);
   end Snapshot_Settings_Key_Of;

   function Same_Snapshot_Settings
     (Settings : Settings_Model;
      Key      : Snapshot_Settings_Key)
      return Boolean is
   begin
      return Snapshot_Settings_Key_Of (Settings) = Key;
   end Same_Snapshot_Settings;

   procedure Safe_Close
     (File : in out Ada.Text_IO.File_Type);

   type Settings_Section is
     (No_Section,
      Filetypes_Section,
      Icons_Section,
      Open_Actions_Section,
      Bookmarks_Section,
      Labels_Section,
      Recent_Section,
      Shortcuts_Section,
      Settings_Section_Name);

   --  Return the stable on-disk token for a color label.
   function Color_Label_Name (Value : Files.Types.Color_Label) return String is
   begin
      case Value is
         when Files.Types.No_Label => return "none";
         when Files.Types.Red      => return "red";
         when Files.Types.Orange   => return "orange";
         when Files.Types.Yellow   => return "yellow";
         when Files.Types.Green    => return "green";
         when Files.Types.Blue     => return "blue";
         when Files.Types.Purple   => return "purple";
         when Files.Types.Gray     => return "gray";
      end case;
   end Color_Label_Name;

   --  Parse a color-label token into Label. Returns False for an unknown token
   --  (leaving Label unchanged) so the caller can skip the invalid entry.
   function Color_Label_From_Name
     (Text  : String;
      Label : out Files.Types.Color_Label)
      return Boolean
 is separate;

   procedure Safe_Close
     (File : in out Ada.Text_IO.File_Type) is
   begin
      if Ada.Text_IO.Is_Open (File) then
         begin
            Ada.Text_IO.Close (File);
         exception
            when others =>
               null;
         end;
      end if;
   end Safe_Close;

   function Trim (Text : String) return String is
      First : Natural := Text'First;
      Last  : Natural := Text'Last;

      function Is_Settings_Space (Value : Character) return Boolean is
      begin
         return Value = ' ' or else Value = ASCII.HT or else Value = ASCII.CR;
      end Is_Settings_Space;
   begin
      while First <= Last and then Is_Settings_Space (Text (First)) loop
         First := First + 1;
      end loop;

      while Last >= First and then Is_Settings_Space (Text (Last)) loop
         Last := Last - 1;
      end loop;

      if First > Last then
         return "";
      end if;

      return Text (First .. Last);
   end Trim;

   function Starts_With (Text : String; Prefix : String) return Boolean is
   begin
      return Text'Length >= Prefix'Length
        and then Text (Text'First .. Text'First + Prefix'Length - 1) = Prefix;
   end Starts_With;

   function Contains (Text : String; Pattern : String) return Boolean is
   begin
      return Ada.Strings.Fixed.Index (Text, Pattern) > 0;
   end Contains;

   function Contains_Line_Break (Text : String) return Boolean is separate;

   function Mapping_Key_Is_Valid (Text : String) return Boolean is
   begin
      return Text /= ""
        and then not Contains_Line_Break (Text)
        and then Ada.Strings.Fixed.Index (Text, "=") = 0;
   end Mapping_Key_Is_Valid;

   function Mapping_Value_Is_Valid (Text : String) return Boolean is
   begin
      --  Reject whitespace-only values: Add_*_Mapping trims before inserting,
      --  so a value like "   " would pass parse validation yet be dropped on
      --  insert. Validating the trimmed form keeps parse and insert in sync.
      return Trim (Text) /= "" and then not Contains_Line_Break (Text);
   end Mapping_Value_Is_Valid;

   function Is_Whole_Placeholder (Text : String) return Boolean is
   begin
      return Text = "{path}"
        or else Text = "{parent}"
        or else Text = "{name}"
        or else Text = "{stem}"
        or else Text = "{extension}";
   end Is_Whole_Placeholder;

   function Contains_Known_Placeholder (Text : String) return Boolean is
   begin
      return Contains (Text, "{path}")
        or else Contains (Text, "{parent}")
        or else Contains (Text, "{name}")
        or else Contains (Text, "{stem}")
        or else Contains (Text, "{extension}");
   end Contains_Known_Placeholder;

   function Strip_Quotes (Text : String) return String is separate;

   function Quoted_Value_Is_Valid (Text : String) return Boolean is separate;

   function Parent_Directory (Path : String) return String is
   begin
      if Path = "" then
         return "";
      end if;

      return Ada.Directories.Containing_Directory (Path);
   exception
      when others =>
         return "";
   end Parent_Directory;

   function Icon_Theme_Name_Is_Valid (Name : String) return Boolean is
      Clean : constant String := Files.Types.To_Lower (Trim (Name));
   begin
      return Clean = "files-basic" or else Clean = "files-high-contrast";
   end Icon_Theme_Name_Is_Valid;

   function Next_Action_Token
     (Text  : String;
      Start : Positive;
      Last  : out Natural;
      Found : out Boolean;
      Valid : out Boolean)
      return String
 is separate;

   function Parse_Action (Text : String) return Open_Action is separate;

   function Clamp_Font_Pixel_Size (Size : Integer) return Positive is
   begin
      if Size < Min_Font_Pixel_Size then
         return Min_Font_Pixel_Size;
      elsif Size > Max_Font_Pixel_Size then
         return Max_Font_Pixel_Size;
      else
         return Size;
      end if;
   end Clamp_Font_Pixel_Size;

   function Default_Settings return Settings_Model is separate;

   --  Return the stable settings-file key suffix for a toggleable detail column.
   --  The suffix is a bare identifier (no spaces) so that assembling a settings
   --  key with " = " never yields a user-text literal (see check_all).
   function Detail_Column_Key (Column : Files.Types.Optional_Detail_Column) return String is
   begin
      case Column is
         when Files.Types.Modified_Column =>
            return "modified";
         when Files.Types.Size_Column =>
            return "size";
         when Files.Types.Filetype_Column =>
            return "filetype";
         when Files.Types.Created_Column =>
            return "created";
         when Files.Types.Permissions_Column =>
            return "permissions";
      end case;
   end Detail_Column_Key;

   --  Return the toggleable column named by Suffix, if any.
   function Detail_Column_For_Key
     (Suffix : String;
      Column : out Files.Types.Optional_Detail_Column)
      return Boolean is
   begin
      for Candidate in Files.Types.Optional_Detail_Column loop
         if Detail_Column_Key (Candidate) = Suffix then
            Column := Candidate;
            return True;
         end if;
      end loop;
      return False;
   end Detail_Column_For_Key;

   --  Return the settings-file token for a detail column in the column-order
   --  list. The optional columns reuse their stable visibility/width suffix; the
   --  mandatory name column is written as "name".
   function Detail_Column_Order_Token (Column : Files.Types.Detail_Column) return String is
      use type Files.Types.Detail_Column;
   begin
      if Column = Files.Types.Name_Column then
         return "name";
      else
         return Detail_Column_Key (Column);
      end if;
   end Detail_Column_Order_Token;

   --  Resolve a column-order token (name or an optional-column suffix) to its
   --  detail column. Accepts "type" as an alias for the filetype column.
   function Detail_Column_For_Order_Token
     (Token  : String;
      Column : out Files.Types.Detail_Column)
      return Boolean
   is
      Optional : Files.Types.Optional_Detail_Column;
   begin
      if Token = "name" then
         Column := Files.Types.Name_Column;
         return True;
      elsif Token = "type" then
         Column := Files.Types.Filetype_Column;
         return True;
      elsif Detail_Column_For_Key (Token, Optional) then
         Column := Optional;
         return True;
      else
         return False;
      end if;
   end Detail_Column_For_Order_Token;

   --  Parse a comma-separated column-order value into a permutation with name
   --  pinned first. Returns False when any token is unknown, duplicated, or the
   --  list is not a full permutation of the known columns.
   function Parse_Detail_Column_Order
     (Value : String;
      Order : out Files.Types.Detail_Column_Order)
      return Boolean
 is separate;

   function Group_Mode_Name (Value : Files.Types.Group_Mode) return String is
   begin
      case Value is
         when Files.Types.No_Grouping =>
            return "none";
         when Files.Types.Group_By_Type =>
            return "type";
         when Files.Types.Group_By_Modified =>
            return "modified";
         when Files.Types.Group_By_Size =>
            return "size";
         when Files.Types.Group_By_Label =>
            return "label";
      end case;
   end Group_Mode_Name;

   function Toggle_Column
     (Settings : Settings_Model;
      Column   : Files.Types.Detail_Column)
      return Settings_Model
   is
      use type Files.Types.Detail_Column;
      Result : Settings_Model := Settings;
   begin
      if Column /= Files.Types.Name_Column then
         Result.Column_Visible (Column) := not Result.Column_Visible (Column);
      end if;
      return Result;
   end Toggle_Column;

   function With_Column_Width
     (Settings : Settings_Model;
      Column   : Files.Types.Detail_Column;
      Width    : Natural)
      return Settings_Model
   is
      Result : Settings_Model := Settings;
   begin
      if Width = 0 then
         Result.Column_Widths (Column) := 0;
      else
         Result.Column_Widths (Column) :=
           Natural'Max (Width, Files.Types.Minimum_Detail_Column_Width);
      end if;
      return Result;
   end With_Column_Width;

   function With_Column_Order
     (Settings : Settings_Model;
      Column   : Files.Types.Detail_Column;
      To_Index : Files.Types.Detail_Column_Index)
      return Settings_Model
   is
      Result : Settings_Model := Settings;
   begin
      Result.Column_Order :=
        Files.Types.Move_Column (Settings.Column_Order, Column, To_Index);
      return Result;
   end With_Column_Order;

   function Cycle_Group_By
     (Settings : Settings_Model)
      return Settings_Model
   is
      use type Files.Types.Group_Mode;
      Result : Settings_Model := Settings;
   begin
      if Settings.Group_By = Files.Types.Group_Mode'Last then
         Result.Group_By := Files.Types.Group_Mode'First;
      else
         Result.Group_By := Files.Types.Group_Mode'Succ (Settings.Group_By);
      end if;
      return Result;
   end Cycle_Group_By;

   function Is_Favorite
     (Settings : Settings_Model;
      Path     : String)
      return Boolean is
   begin
      if Path = "" then
         return False;
      end if;
      for Existing of Settings.Favorite_Paths loop
         if To_String (Existing) = Path then
            return True;
         end if;
      end loop;
      return False;
   end Is_Favorite;

   procedure Toggle_Favorite_Path
     (Settings : in out Settings_Model;
      Path     : String)
   is
      To_Remove : Natural := 0;
   begin
      if Path = "" then
         return;
      end if;
      for Index in
        Settings.Favorite_Paths.First_Index .. Settings.Favorite_Paths.Last_Index
      loop
         if To_String (Settings.Favorite_Paths.Element (Index)) = Path then
            To_Remove := Index;
            exit;
         end if;
      end loop;
      if To_Remove /= 0 then
         Settings.Favorite_Paths.Delete (To_Remove);
      else
         Settings.Favorite_Paths.Append (To_Unbounded_String (Path));
      end if;
   end Toggle_Favorite_Path;

   function Recent_Paths
     (Settings : Settings_Model)
      return String_Vectors.Vector is
   begin
      return Settings.Recent_Paths_Value;
   end Recent_Paths;

   procedure Note_Recent
     (Settings : in out Settings_Model;
      Path     : String)
 is separate;

   procedure Clear_Recent
     (Settings : in out Settings_Model) is
   begin
      Settings.Recent_Paths_Value.Clear;
   end Clear_Recent;

   function Label_Of
     (Settings : Settings_Model;
      Path     : String)
      return Files.Types.Color_Label is
   begin
      if Path = "" then
         return Files.Types.No_Label;
      end if;
      for Entry_Value of Settings.Labels loop
         if To_String (Entry_Value.Path) = Path then
            return Entry_Value.Label;
         end if;
      end loop;
      return Files.Types.No_Label;
   end Label_Of;

   procedure Set_Label
     (Settings : in out Settings_Model;
      Path     : String;
      Label    : Files.Types.Color_Label)
 is separate;

   function Has_Embedded_Placeholder
     (Argument : String)
      return Boolean
   is
   begin
      return Contains_Known_Placeholder (Argument)
        and then not Is_Whole_Placeholder (Argument);
   end Has_Embedded_Placeholder;

   function Has_Embedded_Placeholder
     (Action : Open_Action)
      return Boolean
   is
   begin
      for Argument of Action.Arguments loop
         if Has_Embedded_Placeholder (To_String (Argument)) then
            return True;
         end if;
      end loop;

      return False;
   end Has_Embedded_Placeholder;

   function Has_Unsafe_Placeholder_Usage
     (Action : Open_Action)
      return Boolean is
   begin
      return Contains_Known_Placeholder (To_String (Action.Executable))
        or else Has_Embedded_Placeholder (Action);
   end Has_Unsafe_Placeholder_Usage;

   function Action_Text_Is_Serializable
     (Action : Open_Action)
      return Boolean is
   begin
      if Contains_Line_Break (To_String (Action.Executable)) then
         return False;
      end if;

      for Argument of Action.Arguments loop
         if Contains_Line_Break (To_String (Argument)) then
            return False;
         end if;
      end loop;

      return True;
   end Action_Text_Is_Serializable;

   procedure Add_Extension_Mapping
     (Settings  : in out Settings_Model;
      Extension : String;
      Filetype  : String)
   is
      Key : constant String := Normalize_Extension (Extension);
      Value : constant String := Trim (Filetype);
   begin
      if not Mapping_Key_Is_Valid (Key) or else not Mapping_Value_Is_Valid (Value) then
         return;
      end if;

      if Settings.Extension_Filetypes.Contains (Key) then
         Settings.Extension_Filetypes.Replace (Key, Value);
      else
         Settings.Extension_Filetypes.Insert (Key, Value);
      end if;
   end Add_Extension_Mapping;

   procedure Add_Icon_Mapping
     (Settings : in out Settings_Model;
      Filetype : String;
      Icon     : String) is
      Key : constant String := Trim (Filetype);
      Value : constant String := Trim (Icon);
   begin
      if not Mapping_Key_Is_Valid (Key) or else not Mapping_Value_Is_Valid (Value) then
         return;
      end if;

      if Settings.Icon_Mappings.Contains (Key) then
         Settings.Icon_Mappings.Replace (Key, Value);
      else
         Settings.Icon_Mappings.Insert (Key, Value);
      end if;
   end Add_Icon_Mapping;

   function Modifier_Name_Is_Known (Name : String) return Boolean is
      Clean : constant String := Files.Types.To_Lower (Trim (Name));
   begin
      return Clean = "shift"
        or else Clean = "control"
        or else Clean = "alt"
        or else Clean = "meta";
   end Modifier_Name_Is_Known;

   function Structured_Filetype_Suffix_Is_Known (Name : String) return Boolean is
      Clean : constant String := Files.Types.To_Lower (Trim (Name));
   begin
      return Clean = "json"
        or else Clean = "xml"
        or else Clean = "zip"
        or else Clean = "gzip";
   end Structured_Filetype_Suffix_Is_Known;

   function Plus_Suffix_Is_Structured_Filetype (Token : String) return Boolean is
      Clean : constant String := Trim (Token);
      Plus  : Natural := 0;
   begin
      for Index in Clean'Range loop
         if Clean (Index) = '+' then
            Plus := Index;
         end if;
      end loop;

      return Plus > Clean'First
        and then Plus < Clean'Last
        and then Structured_Filetype_Suffix_Is_Known (Clean (Plus + 1 .. Clean'Last));
   end Plus_Suffix_Is_Structured_Filetype;

   function Modifier_Suffix_Start (Token : String) return Natural is separate;

   function Normalize_Action_Token (Token : String) return String is separate;

   function Action_Token_Modifiers_Are_Known (Token : String) return Boolean is separate;

   function Open_Action_Base_Key_Is_Valid (Text : String) return Boolean is
      Clean : constant String := Trim (Text);
   begin
      if not Mapping_Key_Is_Valid (Clean) then
         return False;
      end if;

      for Character_Value of Clean loop
         if Character_Value = ' '
           or else Character_Value = ASCII.HT
           or else Character_Value = '"'
           or else Character_Value = '['
           or else Character_Value = ']'
         then
            return False;
         end if;
      end loop;

      return True;
   end Open_Action_Base_Key_Is_Valid;

   procedure Add_Open_Action
     (Settings : in out Settings_Model;
      Token    : String;
      Action   : Open_Action)
 is separate;

   function Filetype_For_Extension
     (Settings  : Settings_Model;
      Extension : String)
      return String
   is
      Key : constant String := Normalize_Extension (Extension);
   begin
      if Settings.Extension_Filetypes.Contains (Key) then
         return Settings.Extension_Filetypes.Element (Key);
      end if;

      return "";
   end Filetype_For_Extension;

   function Icon_For_Filetype
     (Settings : Settings_Model;
      Filetype : String)
      return String
   is
      Key : constant String := Trim (Filetype);
   begin
      if Settings.Icon_Mappings.Contains (Key) then
         return Settings.Icon_Mappings.Element (Key);
      end if;

      return "";
   end Icon_For_Filetype;

   function Modifier_Token
     (Modifiers : Guikit.Input.Modifier_Set)
      return String
 is separate;

   --  Build an Open_Action that defers to the host system's default opener.
   --  Returns Found => False when no opener can be located, so callers can
   --  still surface the original "missing open action" diagnostic.
   --
   --  On Linux/Unix the wrapper sidesteps xdg-open's DE-specific routing
   --  (kde-open5 / kde-open6 fail on Qt6-only systems where qtpaths has been
   --  superseded by qtpaths6) by doing the MIME → .desktop → launch dance
   --  itself via xdg-mime + gio launch / gtk-launch, both of which are
   --  Qt-independent. It falls back to xdg-open only when those aren't
   --  available.
   function System_Default_Opener_Action
     (Filetype : String) return Action_Lookup_Result
 is separate;

   function Lookup_Open_Action
     (Settings  : Settings_Model;
      Filetype  : String;
      Modifiers : Guikit.Input.Modifier_Set)
      return Action_Lookup_Result
 is separate;

   --  Parse a boolean setting value. Target is set on "true"/"false"; Valid is
   --  False for anything else (callers turn that into error.settings.invalid_boolean).
   --  Callers that accept mixed case pass a lower-cased value.
   procedure Parse_Boolean
     (Literal : String;
      Target  : in out Boolean;
      Valid   : out Boolean) is
   begin
      Valid := True;
      if Literal = "true" then
         Target := True;
      elsif Literal = "false" then
         Target := False;
      else
         Valid := False;
      end if;
   end Parse_Boolean;

   function Parse
     (Text : String)
      return Settings_Parse_Result
 is separate;

   function Load_File
     (Path : String)
      return Settings_Parse_Result
 is separate;

   function Default_Settings_Text return String is
   begin
      return To_Text (Default_Settings);
   end Default_Settings_Text;

   function View_Mode_Name (Mode : Files.Types.View_Mode) return String is
   begin
      case Mode is
         when Files.Types.Small_Icons =>
            return "small_icons";
         when Files.Types.Large_Icons =>
            return "large_icons";
         when Files.Types.Details =>
            return "details";
      end case;
   end View_Mode_Name;

   function Sort_Field_Name (Field : Sort_Field) return String is
   begin
      case Field is
         when Sort_By_Name =>
            return "name";
         when Sort_By_Filetype =>
            return "filetype";
         when Sort_By_Size =>
            return "size";
         when Sort_By_Created =>
            return "created";
         when Sort_By_Modified =>
            return "modified";
      end case;
   end Sort_Field_Name;

   function Boolean_Name (Value : Boolean) return String is
   begin
      return (if Value then "true" else "false");
   end Boolean_Name;

   function Theme_Name (Value : Theme_Choice) return String is
   begin
      case Value is
         when Theme_Dark =>
            return "dark";
         when Theme_Light =>
            return "light";
         when Theme_High_Contrast =>
            return "high_contrast";
      end case;
   end Theme_Name;

   function Action_Token_Text (Value : String) return String is separate;

   function Action_Text (Action : Open_Action) return String is
      Result : Unbounded_String := Null_Unbounded_String;
   begin
      if Action.Use_Shell then
         Append (Result, "shell:");
      end if;

      Append (Result, Action_Token_Text (To_String (Action.Executable)));
      for Argument of Action.Arguments loop
         Append (Result, " ");
         Append (Result, Action_Token_Text (To_String (Argument)));
      end loop;

      return To_String (Result);
   end Action_Text;

   procedure Sort (Keys : in out String_Vectors.Vector) is
      function Less (Left : UString; Right : UString) return Boolean is
      begin
         return To_String (Left) < To_String (Right);
      end Less;

      package Sorting is new String_Vectors.Generic_Sorting ("<" => Less);
   begin
      Sorting.Sort (Keys);
   end Sort;

   function To_Text
     (Settings : Settings_Model)
      return String
 is separate;

   function Make_Draft
     (Settings : Settings_Model)
      return Settings_Draft is separate;

   function Draft_Mapping_Vectors_Are_Aligned
     (Draft : Settings_Draft)
      return Boolean is
   begin
      return Natural (Draft.Filetype_Keys.Length) = Natural (Draft.Filetype_Values.Length)
        and then Natural (Draft.Icon_Keys.Length) = Natural (Draft.Icon_Values.Length)
        and then Natural (Draft.Open_Action_Keys.Length) = Natural (Draft.Open_Action_Commands.Length);
   end Draft_Mapping_Vectors_Are_Aligned;

   function Draft_Mapping_Key_Error
     (Draft : Settings_Draft)
      return String is separate;

   function Draft_Mapping_Value_Error
     (Draft : Settings_Draft)
      return String is separate;

   type Draft_Mapping_Kind is
     (Draft_Filetype_Mapping,
      Draft_Icon_Mapping,
      Draft_Open_Action_Mapping);

   function Draft_Mapping_Key_Text
     (Kind : Draft_Mapping_Kind;
      Key  : UString)
      return String is
   begin
      case Kind is
         when Draft_Filetype_Mapping =>
            return Normalize_Extension (To_String (Key));
         when Draft_Icon_Mapping =>
            return Trim (To_String (Key));
         when Draft_Open_Action_Mapping =>
            return Normalize_Action_Token (To_String (Key));
      end case;
   end Draft_Mapping_Key_Text;

   function Draft_Settings_Text
     (Draft : Settings_Draft)
      return String
 is separate;

   function Validate_Draft
     (Draft : Settings_Draft)
      return Settings_Parse_Result is separate;

   function Field_Diagnostic
     (Field : Natural;
      Text  : String)
      return String
 is separate;

   function Apply_Draft
     (Settings : Settings_Model;
      Draft    : Settings_Draft)
      return Settings_Parse_Result
 is separate;

   function Save_Draft
     (Path     : String;
      Settings : Settings_Model;
      Draft    : Settings_Draft)
      return Settings_Write_Result
   is
      Applied : constant Settings_Parse_Result := Apply_Draft (Settings, Draft);
   begin
      if not Applied.Success then
         return
           (Success   => False,
            Path      => To_Unbounded_String (Path),
            Error_Key => Applied.Error_Key);
      end if;

      return Save_Text (Path, To_Text (Applied.Settings));
   end Save_Draft;

   function Reset_Draft_To_Defaults return Settings_Draft is
   begin
      return Make_Draft (Default_Settings);
   end Reset_Draft_To_Defaults;

   function Save_Text
     (Path : String;
      Text : String)
      return Settings_Write_Result
 is separate;

   function Ensure_Default_File
     (Path : String)
      return Settings_Write_Result
 is separate;

   function Normalize_Extension
     (Extension : String)
      return String
   is
      Clean : constant String := Trim (Extension);
   begin
      if Clean = "" then
         return "";
      elsif Clean (Clean'First) = '.' then
         if Clean'Length = 1 then
            return "";
         end if;
         return Files.Types.To_Lower (Trim (Clean (Clean'First + 1 .. Clean'Last)));
      else
         return Files.Types.To_Lower (Clean);
      end if;
   end Normalize_Extension;

   function Make_Action
     (Executable : String;
      Arguments  : String_Vectors.Vector;
      Use_Shell  : Boolean := False)
      return Open_Action is
   begin
      return
        (Executable => To_Unbounded_String (Executable),
         Arguments  => Arguments,
         Use_Shell  => Use_Shell);
   end Make_Action;

   function Expand_Placeholders
     (Action : Open_Action;
      Path   : String)
      return Open_Action
 is separate;

end Files.Settings;
