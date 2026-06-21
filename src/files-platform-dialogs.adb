with Ada.Strings.Unbounded;

package body Files.Platform.Dialogs is
   use Ada.Strings.Unbounded;
   use type Files.File_System.Native_API_Binding_Status;

   function Profile return Native_Dialog_Profile is
   begin
      return
        (Binding_Status     => Files.File_System.Native_API_Binding_Missing,
         Backend_Name       => To_Unbounded_String ("none"),
         Native_API_Name    => To_Unbounded_String ("none"),
         Binding_Unit       => To_Unbounded_String ("Files.Platform.Dialogs"),
         Required_Library   => Null_Unbounded_String,
         Required_Framework => Null_Unbounded_String,
         Current_Target     => False,
         Can_Open_File      => False,
         Can_Save_File      => False,
         Uses_Shell         => False,
         Mode_Preflight     => True,
         Settings_Import_Export => True,
         Extension_Filtering => True,
         User_Mediated      => True,
         Path_Result_Normalization => True);
   end Profile;

   function Available return Boolean is
      Dialog_Profile : constant Native_Dialog_Profile := Profile;
   begin
      return
        Dialog_Profile.Binding_Status = Files.File_System.Native_API_Binding_Available
        and then Dialog_Profile.Can_Open_File
        and then Dialog_Profile.Can_Save_File
        and then not Dialog_Profile.Uses_Shell;
   end Available;

   function Backend_Name return String is
   begin
      return To_String (Profile.Backend_Name);
   end Backend_Name;
end Files.Platform.Dialogs;
