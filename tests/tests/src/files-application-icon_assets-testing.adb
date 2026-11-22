package body Files.Application.Icon_Assets.Testing is

   function Disk_Icon_Asset
     (Icon_Id    : String;
      Theme_Name : String)
      return String renames Files.Application.Icon_Assets.Disk_Icon_Asset;

   function Builtin_Icon_Asset
     (Icon_Id    : String;
      Theme_Name : String)
      return String renames Files.Application.Icon_Assets.Builtin_Icon_Asset;

   function Icon_Asset
     (Icon_Id    : String;
      Theme_Name : String)
      return String renames Files.Application.Icon_Assets.Icon_Asset;

end Files.Application.Icon_Assets.Testing;
