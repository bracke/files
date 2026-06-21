with Ada.Directories;

with I18N.Arguments;
with I18N.Result;
with I18N.Runtime;

package body Files.Localization is
   use type I18N.Result.Render_Status;

   Runtime     : I18N.Runtime.Instance;
   Initialized : Boolean := False;
   Available   : Boolean := False;

   function Catalog_Path return String;
   procedure Ensure_Initialized;

   function Catalog_Path return String is
   begin
      if Ada.Directories.Exists ("share/files.catalog") then
         return "share/files.catalog";
      elsif Ada.Directories.Exists ("../../share/files.catalog") then
         return "../../share/files.catalog";
      elsif Ada.Directories.Exists ("../share/files.catalog") then
         return "../share/files.catalog";
      end if;

      return "share/files.catalog";
   end Catalog_Path;

   procedure Ensure_Initialized is
   begin
      if not Initialized then
         I18N.Runtime.Initialize (Runtime, Catalog_Path);
         Available := I18N.Runtime.Is_Valid (Runtime);
         Initialized := True;
      end if;
   end Ensure_Initialized;

   function Text
     (Key    : String;
      Locale : String := "en")
      return String
   is
      Args   : I18N.Arguments.Arguments;
      Result : I18N.Result.Render_Result;
   begin
      Ensure_Initialized;

      if not Available then
         return Key;
      end if;

      Result :=
        I18N.Runtime.Render
          (Item      => Runtime,
           Locale    => Locale,
           Key       => Key,
           Arguments => Args);

      if Result.Status = I18N.Result.Success then
         return I18N.Result.Output_Text (Result.Text);
      end if;

      return Key;
   end Text;

end Files.Localization;
