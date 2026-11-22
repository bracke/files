with Ada.Strings.Unbounded;

package body Files.Folder_Size.Testing is

   function Target (Scan : Session) return String is
     (if Scan.Next_Result <= Natural (Scan.Batch.Length)
      then Ada.Strings.Unbounded.To_String (Scan.Batch (Scan.Next_Result).Path)
      else "");

   function Batch_Length (Scan : Session) return Natural is (Natural (Scan.Batch.Length));

   procedure Fail_Result_Reads (Count : Natural) is
   begin
      Test_Unreadable_Results := Count;
   end Fail_Result_Reads;

   function Helper_Starts return Natural is (Test_Helper_Starts);

   function Is_Active (Scan : Session) return Boolean renames Files.Folder_Size.Is_Active;

end Files.Folder_Size.Testing;
