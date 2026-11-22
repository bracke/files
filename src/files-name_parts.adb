with Files.Text_Case;
with Hostkit.Path_Text;

package body Files.Name_Parts is

   use Files.Text_Case;

   function Extension_Start (Name : String) return Natural is
   begin
      for Index in reverse Name'Range loop
         if Name (Index) = '.' then
            return (if May_Start_Extension (Name, Index) then Index else 0);
         end if;
      end loop;
      return 0;
   end Extension_Start;

   function Stem_Of (Name : String) return String is
      Dot : constant Natural := Extension_Start (Name);
   begin
      return (if Dot = 0 then Name else Name (Name'First .. Dot - 1));
   end Stem_Of;

   function Extension_Of (Name : String) return String is
      Dot : constant Natural := Extension_Start (Name);
   begin
      return (if Dot = 0 then "" else Name (Dot + 1 .. Name'Last));
   end Extension_Of;

   --  Whether a folder named Name is a package that shows as one item, its
   --  extension naming what it is (macOS's "Mail.app", "Photos.photoslibrary",
   --  "Notes.rtfd"): app, appex, bundle, component, framework, kext, mpkg,
   --  pkg, plugin, prefpane, qlgenerator, mdimporter, saver, xpc, rtfd,
   --  photoslibrary, xcodeproj, xcworkspace, playground, matched without
   --  regard to ASCII case.
   function Is_Package_Name (Name : String) return Boolean is
      E : constant String := To_Lower_Ascii (Extension_Of (Name));
   begin
      return E = "app" or else E = "appex" or else E = "bundle" or else E = "component"
        or else E = "framework" or else E = "kext" or else E = "mpkg" or else E = "pkg"
        or else E = "plugin" or else E = "prefpane" or else E = "qlgenerator" or else E = "mdimporter"
        or else E = "saver" or else E = "xpc" or else E = "rtfd" or else E = "photoslibrary"
        or else E = "xcodeproj" or else E = "xcworkspace" or else E = "playground";
   end Is_Package_Name;

   function Name_Stem (Name : String; Is_Directory : Boolean) return String is
     (if Is_Directory and then not Is_Package_Name (Name) then Name else Stem_Of (Name));

   function Name_Extension (Name : String; Is_Directory : Boolean) return String is
     (if Is_Directory and then not Is_Package_Name (Name) then "" else Extension_Of (Name));

   function Leaf_Of (Path : String) return String renames Hostkit.Path_Text.Leaf;
end Files.Name_Parts;
