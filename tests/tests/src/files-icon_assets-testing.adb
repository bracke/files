package body Files.Icon_Assets.Testing is

   function Disk_Icon_Asset
     (Icon_Id    : String;
      Theme_Name : String)
      return String renames Files.Icon_Assets.Disk_Icon_Asset;

   function Builtin_Icon_Asset
     (Icon_Id    : String;
      Theme_Name : String)
      return String renames Files.Icon_Assets.Builtin_Icon_Asset;

end Files.Icon_Assets.Testing;
