with Files.File_System;
with Files.Types;

--  Platform native file-dialog integration contract.
package Files.Platform.Dialogs is
   subtype UString is Files.Types.UString;

   type Native_Dialog_Profile is record
      Binding_Status     : Files.File_System.Native_API_Binding_Status :=
        Files.File_System.Native_API_Binding_Missing;
      Backend_Name       : UString;
      Native_API_Name    : UString;
      Binding_Unit       : UString;
      Required_Library   : UString;
      Required_Framework : UString;
      Current_Target     : Boolean := False;
      Can_Open_File      : Boolean := False;
      Can_Save_File      : Boolean := False;
      Uses_Shell         : Boolean := False;
      Mode_Preflight     : Boolean := True;
      Settings_Import_Export : Boolean := True;
      Extension_Filtering : Boolean := True;
      User_Mediated      : Boolean := True;
      Path_Result_Normalization : Boolean := True;
   end record;

   --  Return native file-dialog binding metadata for this build.
   --
   --  @return Dialog backend profile; unsupported builds return a non-shell profile.
   function Profile return Native_Dialog_Profile;

   --  Return whether a native file-dialog backend can be used now.
   --
   --  @return True when both open-file and save-file dialogs are available.
   function Available return Boolean;

   --  Return the native dialog backend display name.
   --
   --  @return Stable backend name used in structured dialog results.
   function Backend_Name return String;
end Files.Platform.Dialogs;
