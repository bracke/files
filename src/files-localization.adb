with Files.Diagnostics;
with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Containers.Vectors;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Hash;

with Messages.Arguments;
with Messages.Result;

with Files.Environment;
with Files.IO.Fs_Primitives;
with Files.Resources;

with Hostkit.Host;
with Humanize.Catalogs;
with I18N.Locales;
with Files.Text_Case;

package body Files.Localization is
   use Ada.Strings.Unbounded;
   use type Messages.Result.Render_Status;

   package String_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Natural,
      Element_Type => Unbounded_String);

   Runtime     : aliased Messages.Runtime.Instance;
   Initialized : Boolean := False;
   Available   : Boolean := False;
   Loaded_Locales : String_Vectors.Vector;
   Humanize_Loaded : Boolean := False;

   --  Text is asked per listed item and from every label of every snapshot
   --  rebuild (hover included), so it memoizes the two costly steps. Like the
   --  rest of this package's state the memos are main-thread only: a task
   --  must not call Text (see Files.Jobs.Scavenger).
   --
   --  System_Locale, worked out once: the process never changes its locale
   --  variables, so reading three of them (and allocating each) on every
   --  Text call was pure cost. Reread_Locale_Environment forgets it, for a
   --  caller that does change them (a test switching LC_ALL).
   Locale_Memo_Valid       : Boolean := False;
   Locale_Memo_Value       : Unbounded_String;

   --  Rendered text by effective locale and key. A render depends only on the
   --  catalogs loaded into Runtime, so Load_Locale empties it whenever it
   --  loads another; it is also emptied past Max_Cached_Texts, which bounds a
   --  caller that passes ever-new keys.
   package Text_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => String,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=");

   Max_Cached_Texts : constant := 16_384;
   Text_Cache       : Text_Maps.Map;

   function Environment_Locale (Name : String) return String;
   function Environment_Portable_Locale (Name : String) return Boolean;
   function Configured_Category_Locale (Category_Key : String) return String;
   function Native_System_Locale return String;
   function Resolve_System_Locale return String;
   function Uncached_Text
     (Key              : String;
      Effective_Locale : String)
      return String;
   function Render_Text
     (Key    : String;
      Locale : String)
      return String;
   function Portable_Locale (Value : String) return Boolean;
   function Catalog_Path return String;
   function Locale_Catalog_Path (Locale : String) return String;
   function Locale_Loaded (Locale : String) return Boolean;
   procedure Load_Locale (Locale : String);
   procedure Ensure_Initialized;

   function Normalize_Locale (Value : String) return String is
      Raw  : constant String := Ada.Strings.Fixed.Trim (Value, Ada.Strings.Both);
      Last : Natural := Raw'Last;

      --  The @modifier (sr_RS.UTF-8@latin), lower case, or "".
      function Modifier return String is
      begin
         for At_Sign in Raw'Range loop
            if Raw (At_Sign) = '@' then
               for Index in At_Sign + 1 .. Raw'Last loop
                  if Raw (Index) = '.' then
                     return Files.Text_Case.To_Lower_Ascii (Raw (At_Sign + 1 .. Index - 1));
                  end if;
               end loop;
               return Files.Text_Case.To_Lower_Ascii (Raw (At_Sign + 1 .. Raw'Last));
            end if;
         end loop;
         return "";
      end Modifier;

      --  The script subtag a well-known glibc modifier names, or "".
      function Modifier_Script return String is
        (if Modifier = "latin" then "Latn"
         elsif Modifier = "cyrillic" then "Cyrl"
         elsif Modifier = "devanagari" then "Deva"
         else "");

      --  The variant subtag a well-known glibc modifier names, or "".
      function Modifier_Variant return String is
        (if Modifier = "valencia" then "valencia" else "");

      --  A name that can only be a locale's: subtags of ASCII letters and
      --  digits, none empty, separated by '_' or '-'.
      function Well_Formed (Base : String) return Boolean is
        (Base'Length > 0
         and then Base (Base'First) not in '_' | '-'
         and then Base (Base'Last) not in '_' | '-'
         and then (for all Index in Base'Range =>
                     Base (Index) in 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9'
                     or else (Base (Index) in '_' | '-'
                              and then Index < Base'Last
                              and then Base (Index + 1) not in '_' | '-')));
   begin
      --  The normalized value is retained and is also embedded in a locale
      --  catalog pathname. Keep it a small locale identifier, never an
      --  attacker-controlled path or an unbounded cache key.
      if Raw'Length = 0 or else Raw'Length > 64 then
         return "en";
      end if;

      --  The codeset (.UTF-8) and the modifier (@latin) are no subtags.
      for Index in Raw'Range loop
         if Raw (Index) = '.' or else Raw (Index) = '@' then
            Last := Index - 1;
            exit;
         end if;
      end loop;

      declare
         Base : constant String := Raw (Raw'First .. Last);
      begin
         if Base = "C" or else Base = "POSIX" or else not Well_Formed (Base) then
            return "en";
         end if;

         declare
            --  I18N's canonical form: hyphens, BCP 47 casing, CLDR's language
            --  aliases (iw is he, sh is sr-Latn).
            Canonical : constant String := I18N.Locales.Canonicalize (Base);
            Language  : constant Natural :=
              (if Ada.Strings.Fixed.Index (Canonical, "-") = 0 then Canonical'Last
               else Ada.Strings.Fixed.Index (Canonical, "-") - 1);
            Rest      : constant String := Canonical (Language + 1 .. Canonical'Last);
            --  Whether the subtag after the language is a script (Latn).
            Has_Script : constant Boolean :=
              Rest'Length >= 5
              and then (Rest'Length = 5 or else Rest (Rest'First + 5) = '-')
              and then (for all C of Rest (Rest'First + 1 .. Rest'First + 4) => C in 'A' .. 'Z' | 'a' .. 'z');
            --  A modifier naming a script or a variant is kept, as the
            --  catalogs spell it (sr_RS@latin is sr-Latn-RS, ca_ES@valencia
            --  ca-ES-valencia); the others (euro, say) say nothing a catalog
            --  differs by.
            Script  : constant String :=
              (if Has_Script or else Modifier_Script = "" then "" else "-" & Modifier_Script);
            Variant : constant String := (if Modifier_Variant = "" then "" else "-" & Modifier_Variant);
         begin
            return Canonical (Canonical'First .. Language) & Script & Rest & Variant;
         end;
      end;
   end Normalize_Locale;

   function Layout_Is_Right_To_Left return Boolean is
     (I18N.Locales.Is_Right_To_Left (System_Locale));

   function System_Locale return String is
   begin
      if not Locale_Memo_Valid then
         Locale_Memo_Value := To_Unbounded_String (Resolve_System_Locale);
         Locale_Memo_Valid := True;
      end if;
      return To_String (Locale_Memo_Value);
   end System_Locale;

   function Resolve_System_Locale return String is
      --  System_Locale's answer worked out afresh from the environment.
      Variable : constant String := Files.Environment.Message_Locale;
   begin
      if Variable /= "" then
         return Normalize_Locale (Variable);
      end if;

      declare
         Native : constant String := Native_System_Locale;
      begin
         if Native /= "" then
            return Native;
         end if;
      end;

      return "en";
   end Resolve_System_Locale;

   --  The date or the number category's locale, worked out once: it is
   --  asked per formatted date or size, and where the variables do not decide
   --  it the desktop's configuration files are read. Reread_Locale_Environment
   --  forgets it.
   type Locale_Category is (Time_Category, Number_Category);

   type Category_Memo is record
      Valid : Boolean := False;
      Value : Unbounded_String;
   end record;

   Category_Memos : array (Locale_Category) of Category_Memo;

   function System_Category_Locale (Category : Locale_Category) return String is
      Category_Key : constant String :=
        (case Category is
            when Time_Category   => "LC_TIME",
            when Number_Category => "LC_NUMERIC");
      Memo         : Category_Memo renames Category_Memos (Category);

      --  The variables decide by the precedence messages follow too
      --  (Files.Environment.Locale_Variable), with one difference kept on
      --  purpose: a portable LANG (C, POSIX) says nothing about dates and
      --  numbers, so the desktop's configured formats come before it. The
      --  message locale takes such a LANG as English.
      function Resolve return String is
         Decider : constant String := Files.Environment.Locale_Variable (Category_Key);
         Value   : constant String := (if Decider = "" then "" else Environment_Locale (Decider));
         Lang    : constant String := (if Decider = "LANG" then Value else "");
      begin
         if Value /= "" and then not (Decider = "LANG" and then Environment_Portable_Locale ("LANG")) then
            return Value;
         end if;

         declare
            Config : constant String := Configured_Category_Locale (Category_Key);
         begin
            if Config /= "" then
               return Config;
            elsif Lang /= "" then
               return Lang;
            end if;
         end;

         declare
            Native : constant String := Native_System_Locale;
         begin
            if Native /= "" then
               return Native;
            end if;
         end;

         return "en";
      end Resolve;
   begin
      if not Memo.Valid then
         Memo := (Valid => True, Value => To_Unbounded_String (Resolve));
      end if;
      return To_String (Memo.Value);
   end System_Category_Locale;

   procedure Reread_Locale_Environment is
   begin
      Locale_Memo_Valid := False;
      Category_Memos := [others => (Valid => False, Value => Null_Unbounded_String)];
   end Reread_Locale_Environment;

   function System_Time_Locale return String is (System_Category_Locale (Time_Category));

   function System_Number_Locale return String is (System_Category_Locale (Number_Category));

   function Environment_Locale (Name : String) return String is
   begin
      declare
         Value : constant String :=
           Ada.Strings.Fixed.Trim (Files.Environment.Value (Name), Ada.Strings.Both);
      begin
         if Value'Length = 0 then
            return "";
         end if;

         return Normalize_Locale (Value);
      end;
   end Environment_Locale;

   function Environment_Portable_Locale (Name : String) return Boolean is
   begin
      return Files.Environment.Is_Set (Name)
        and then Portable_Locale (Files.Environment.Value (Name));
   end Environment_Portable_Locale;

   function Native_System_Locale return String is
      --  One question for every host: Hostkit reads the Windows and macOS
      --  settings and answers "" on POSIX, where the locale lives in the
      --  environment that the callers below read.
      Raw : constant String := Hostkit.Host.Native_Locale;
   begin
      if Raw = "" then
         return "";
      end if;

      return Normalize_Locale (Raw);
   end Native_System_Locale;

   function Configured_Category_Locale (Category_Key : String) return String is
      --  Where the desktop keeps its formats is the host's to know
      --  (Hostkit.Host.Configured_Format_Locale); normalising is files'.
      Value : constant String :=
        Hostkit.Host.Configured_Format_Locale
          ((if Category_Key = "LC_TIME" then Hostkit.Host.Time_Formats else Hostkit.Host.Number_Formats),
           Files.Environment.Value ("HOME"));
   begin
      return (if Value = "" then "" else Normalize_Locale (Value));
   end Configured_Category_Locale;

   function Portable_Locale (Value : String) return Boolean is
      Raw  : constant String := Ada.Strings.Fixed.Trim (Value, Ada.Strings.Both);
      Last : Natural := Raw'Last;
   begin
      if Raw'Length = 0 then
         return True;
      end if;

      for Index in Raw'Range loop
         if Raw (Index) = '.' or else Raw (Index) = '@' then
            Last := Index - 1;
            exit;
         end if;
      end loop;

      if Last < Raw'First then
         return True;
      end if;

      declare
         Base : constant String := Raw (Raw'First .. Last);
      begin
         return Base = "C" or else Base = "POSIX";
      end;
   end Portable_Locale;

   function Catalog_Path return String is
   begin
      return Files.Resources.Share_Path ("files.catalog");
   end Catalog_Path;

   function Locale_Catalog_Path (Locale : String) return String is
   begin
      return Files.Resources.Share_Path
        ("locales/files-" & Locale & ".catalog");
   end Locale_Catalog_Path;

   function Locale_Loaded (Locale : String) return Boolean is
   begin
      for Item of Loaded_Locales loop
         if To_String (Item) = Locale then
            return True;
         end if;
      end loop;

      return False;
   end Locale_Loaded;

   function Load_Locale_Shard
     (Item : in out Messages.Runtime.Runtime;
      Path : String)
      return Boolean
   is
      use type Messages.Runtime.Load_Status;
      Shard : Messages.Runtime.Load_Result;
   begin
      --  Not Load: a strict load that fails leaves the whole runtime invalid.
      Messages.Runtime.Load_File (Item, Path, Shard);
      if Shard.Status /= Messages.Runtime.Loaded then
         Files.Diagnostics.Trace
           ("Files.Localization", "locale_catalog_skipped=" & Path & ",status=" & Shard.Status'Image);
         return False;
      end if;
      return True;
   end Load_Locale_Shard;

   procedure Load_Locale (Locale : String) is
      Normalized : constant String := Normalize_Locale (Locale);
      Path       : constant String := Locale_Catalog_Path (Normalized);
   begin
      if not Available or else Locale_Loaded (Normalized) then
         return;
      end if;

      --  refusal-safe: a catalog not seen is not loaded, and its texts fall
      --  back to the default locale's, as an unreadable one's do.
      if Files.IO.Fs_Primitives.Exists (Path) then
         declare
            Loaded : constant Boolean := Load_Locale_Shard (Runtime, Path);
            pragma Unreferenced (Loaded);
         begin
            null;
         end;
      end if;
      --  humanize's phrases in this locale's language too, beside its defaults.
      if Humanize_Loaded then
         declare
            use type Messages.Runtime.Load_Status;
            Phrases : Messages.Runtime.Load_Result;
         begin
            --  A failed load leaves the runtime as it was: humanize keeps its
            --  default wording for this language.
            Humanize.Catalogs.Load_Phrases (Runtime, Phrases, Normalized);
            if Phrases.Status /= Messages.Runtime.Loaded then
               Files.Diagnostics.Trace
                 ("Files.Localization",
                  "humanize_phrases_skipped=" & Normalized & ",status=" & Phrases.Status'Image);
            end if;
         end;
      end if;

      Loaded_Locales.Append (To_Unbounded_String (Normalized));
      --  The new catalog may answer what an earlier render fell back on.
      Text_Cache.Clear;

      --  Then its parent, one subtag less (sr-Latn-RS, sr-Latn, sr), as the
      --  runtime falls back when it renders.
      for Index in reverse Normalized'Range loop
         if Normalized (Index) = '-' then
            Load_Locale (Normalized (Normalized'First .. Index - 1));
            exit;
         end if;
      end loop;
   end Load_Locale;

   procedure Ensure_Initialized is
   begin
      if not Initialized then
         Messages.Runtime.Initialize (Runtime, Catalog_Path);
         Available := Messages.Runtime.Is_Valid (Runtime);
         Initialized := True;
         --  humanize's own messages, beside files' catalog in one runtime.
         if Available then
            declare
               use type Messages.Runtime.Load_Status;
               Result : Messages.Runtime.Load_Result;
            begin
               --  No phrase translations yet: Load_Locale adds each locale's
               --  language as files first renders in it.
               Humanize.Catalogs.Load_Defaults (Runtime, Result, Locale => "en");
               --  Without them humanize answers a non-Ok status, and the
               --  callers keep files' own wording.
               Humanize_Loaded := Result.Status = Messages.Runtime.Loaded;
            end;
         end if;
         Load_Locale (System_Locale);
         Load_Locale (System_Time_Locale);
         Load_Locale (System_Number_Locale);
      end if;
   end Ensure_Initialized;

   function Text
     (Key    : String;
      Locale : String := "")
      return String
   is
      Effective_Locale : constant String :=
        (if Locale'Length = 0 then System_Locale else Normalize_Locale (Locale));
      --  A locale is a short identifier (Normalize_Locale), never a NUL.
      Cache_Key : constant String := Effective_Locale & ASCII.NUL & Key;
      Found     : constant Text_Maps.Cursor := Text_Cache.Find (Cache_Key);
   begin
      --  A hit was rendered after this locale was loaded and before any later
      --  load (which empties the cache), so it is what a render would give now.
      if Text_Maps.Has_Element (Found) then
         return Text_Maps.Element (Found);
      end if;

      Ensure_Initialized;
      Load_Locale (Effective_Locale);

      declare
         Rendered : constant String := Uncached_Text (Key, Effective_Locale);
      begin
         if Natural (Text_Cache.Length) >= Max_Cached_Texts then
            Text_Cache.Clear;
         end if;
         Text_Cache.Include (Cache_Key, Rendered);
         return Rendered;
      end;
   end Text;

   --  Text's answer for an already normalized locale whose catalogs are
   --  loaded: the regional message, else its language's, else Key.
   --
   --  Which catalog defines the key decides, never what the text says: a
   --  regional value that happens to equal the English one (zh-Hant's "MB",
   --  where zh names the unit) is still the region's own and must win over
   --  the language's.
   function Uncached_Text
     (Key              : String;
      Effective_Locale : String)
      return String
   is
      Rendered : constant String := Render_Text (Key, Effective_Locale);
   begin
      for Index in Effective_Locale'Range loop
         if Effective_Locale (Index) = '-' then
            declare
               Language : constant String := Effective_Locale (Effective_Locale'First .. Index - 1);
               Found    : constant Messages.Runtime.Resolve_Result :=
                 (if Available then Messages.Runtime.Resolve (Runtime, Effective_Locale, Key)
                  else (others => <>));
               Resolver : constant String :=
                 Files.Text_Case.To_Lower_Ascii (Messages.Runtime.Resolved_Locale (Found));
               --  A catalog more specific than the language's (the region's,
               --  or a script's in between) holds the key.
               Regional : constant Boolean :=
                 Messages.Runtime."=" (Found.Status, Messages.Runtime.Found)
                 and then Resolver'Length > Language'Length
                 and then Resolver (Resolver'First .. Resolver'First + Language'Length)
                            = Files.Text_Case.To_Lower_Ascii (Language) & '-';
            begin
               if Regional then
                  return Rendered;
               end if;
               declare
                  Language_Rendered : constant String := Render_Text (Key, Language);
               begin
                  --  The language has no message either: whatever the chain
                  --  gave (the default's), or Key.
                  return (if Language_Rendered = Key then Rendered else Language_Rendered);
               end;
            end;
         end if;
      end loop;

      return Rendered;
   end Uncached_Text;

   function Render_Text
     (Key    : String;
      Locale : String)
      return String
   is
      Args   : Messages.Arguments.Arguments;
      Result : Messages.Result.Render_Result;
   begin
      Ensure_Initialized;

      if not Available then
         return Key;
      end if;

      Result :=
        Messages.Runtime.Render
          (Item      => Runtime,
           Locale    => Locale,
           Key       => Key,
           Arguments => Args);

      if Result.Status = Messages.Result.Success then
         return Messages.Result.Output_Text (Result.Text);
      end if;

      return Key;
   end Render_Text;

   function Humanize_Available return Boolean is
   begin
      Ensure_Initialized;
      return Humanize_Loaded;
   end Humanize_Available;

   function Humanize_Context (Locale : String := "") return Humanize.Contexts.Context is
      Effective_Locale : constant String :=
        (if Locale'Length = 0 then System_Locale else Normalize_Locale (Locale));
   begin
      Ensure_Initialized;
      Load_Locale (Effective_Locale);
      return Humanize.Contexts.Create (Runtime'Access, Effective_Locale);
   end Humanize_Context;

   function Count_Text
     (Key    : String;
      Count  : Natural;
      Locale : String := "")
      return String
   is
      Effective_Locale : constant String :=
        (if Locale'Length = 0 then System_Locale else Normalize_Locale (Locale));

      function Language (Tag : String) return String is
      begin
         for Index in Tag'Range loop
            if Tag (Index) = '-' or else Tag (Index) = '_' then
               return Files.Text_Case.To_Lower_Ascii (Tag (Tag'First .. Index - 1));
            end if;
         end loop;
         return Files.Text_Case.To_Lower_Ascii (Tag);
      end Language;
   begin
      Ensure_Initialized;
      Load_Locale (Effective_Locale);
      if not Available then
         return "";
      end if;
      declare
         Found : constant Messages.Runtime.Resolve_Result :=
           Messages.Runtime.Resolve (Runtime, Effective_Locale, Key);
         use type Messages.Runtime.Resolve_Status;
      begin
         if Found.Status /= Messages.Runtime.Found
           or else Language (Messages.Runtime.Resolved_Locale (Found)) /= Language (Effective_Locale)
         then
            return "";
         end if;
      end;
      declare
         Args   : Messages.Arguments.Arguments;
         Result : Messages.Result.Render_Result;
      begin
         Messages.Arguments.Set_Integer (Args, "count", Long_Long_Integer (Count));
         Result := Messages.Runtime.Render (Runtime, Effective_Locale, Key, Args);
         return
           (if Result.Status = Messages.Result.Success
            then Messages.Result.Output_Text (Result.Text) else "");
      end;
   end Count_Text;

   function Text
     (Key       : String;
      Arguments : Argument_List;
      Locale    : String := "")
      return String
   is
      Effective_Locale : constant String :=
        (if Locale'Length = 0 then System_Locale else Normalize_Locale (Locale));
      Args   : Messages.Arguments.Arguments;
      Result : Messages.Result.Render_Result;
   begin
      Ensure_Initialized;
      Load_Locale (Effective_Locale);
      if not Available then
         return Key;
      end if;
      for Item of Arguments loop
         Messages.Arguments.Set (Args, To_String (Item.Name), To_String (Item.Value));
      end loop;
      Result := Messages.Runtime.Render (Runtime, Effective_Locale, Key, Args);
      return
        (if Result.Status = Messages.Result.Success
         then Messages.Result.Output_Text (Result.Text) else Key);
   end Text;

   function Label_Value
     (Label  : String;
      Value  : String;
      Locale : String := "")
      return String is
     (Text
        ("format.label_value",
         Argument_List'
           [(To_Unbounded_String ("label"), To_Unbounded_String (Label)),
            (To_Unbounded_String ("value"), To_Unbounded_String (Value))],
         Locale));

   function Text
     (Key    : String;
      Name   : String;
      Value  : String;
      Locale : String := "")
      return String is
     (Text (Key, Argument_List'[1 => (To_Unbounded_String (Name), To_Unbounded_String (Value))], Locale));

end Files.Localization;
