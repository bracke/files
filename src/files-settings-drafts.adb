with Ada.Strings.Unbounded;
with Files.Text_Basics;

package body Files.Settings.Drafts is

   use Ada.Strings.Unbounded;

   function Trim (Text : String) return String renames Files.Text_Basics.Trim_Blanks;

   function Make_Draft
     (Settings : Settings_Model)
      return Settings_Draft is separate;

   procedure Normalize_Draft
     (Draft : in out Settings_Draft) is separate;

   function Refresh_Draft
     (Draft  : Settings_Draft;
      Before : Settings_Model;
      After  : Settings_Model)
      return Settings_Draft
   is
      Result : Settings_Draft := Draft;
   begin
      for Setting in Scalar_Setting loop
         if Is_Pane_Setting (Setting) then
            declare
               Now : constant String := Scalar_Text (After, Setting);
            begin
               if Scalar_Text (Before, Setting) /= Now then
                  Result.Scalars (Setting) := To_Unbounded_String (Now);
               end if;
            end;
         end if;
      end loop;
      return Result;
   end Refresh_Draft;

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
            return Files.File_Types.Normalize_Extension (To_String (Key));
         when Draft_Icon_Mapping =>
            return Trim (To_String (Key));
         when Draft_Open_Action_Mapping =>
            return Normalize_Action_Token (To_String (Key));
      end case;
   end Draft_Mapping_Key_Text;

   --  Return Draft with each mapping editor's selected key/value merged into
   --  its row vectors: replacing the row whose normalized key matches (which
   --  also writes that key in its normal form), or appended as a new row. The
   --  settings pane keeps its selected fields on a row of its own (typing into
   --  an empty group starts one), so an appended row comes only from a draft
   --  built elsewhere with fields that name no row. An edit with an empty key
   --  and value is not a row. Draft_Settings_Text and Apply_Draft both read
   --  the merged rows.
   function With_Pending_Rows
     (Draft : Settings_Draft)
      return Settings_Draft
   is
      Result : Settings_Draft := Draft;

      procedure Upsert
        (Keys   : in out String_Vectors.Vector;
         Values : in out String_Vectors.Vector;
         Kind   : Draft_Mapping_Kind;
         Key    : UString;
         Value  : UString)
      is
         Key_Text : constant String := Draft_Mapping_Key_Text (Kind, Key);
      begin
         if Length (Key) = 0 and then Length (Value) = 0 then
            return;
         end if;

         for Index in 1 .. Natural (Keys.Length) loop
            if Draft_Mapping_Key_Text (Kind, Keys.Element (Index)) = Key_Text then
               Keys.Replace_Element (Index, To_Unbounded_String (Key_Text));
               Values.Replace_Element (Index, Value);
               return;
            end if;
         end loop;

         Keys.Append (To_Unbounded_String (Key_Text));
         Values.Append (Value);
      end Upsert;
   begin
      Upsert
        (Result.Filetype_Keys,
         Result.Filetype_Values,
         Draft_Filetype_Mapping,
         Draft.Filetype_Extension,
         Draft.Filetype_Value);
      Upsert (Result.Icon_Keys, Result.Icon_Values, Draft_Icon_Mapping, Draft.Icon_Filetype, Draft.Icon_Value);
      Upsert
        (Result.Open_Action_Keys,
         Result.Open_Action_Commands,
         Draft_Open_Action_Mapping,
         Draft.Open_Action_Token,
         Draft.Open_Action_Command);
      return Result;
   end With_Pending_Rows;

   function Draft_Settings_Text
     (Draft : Settings_Draft)
      return String
 is separate;

   function Validate_Draft
     (Draft : Settings_Draft)
      return Settings_Parse_Result is separate;

   function Draft_After_Save
     (Draft : Settings_Draft;
      Saved : Settings_Model)
      return Settings_Draft is separate;

   function Apply_Draft
     (Settings : Settings_Model;
      Draft    : Settings_Draft)
      return Settings_Parse_Result
 is separate;

   function Reset_Draft_To_Defaults return Settings_Draft is
   begin
      return Make_Draft (Default_Settings);
   end Reset_Draft_To_Defaults;

end Files.Settings.Drafts;
