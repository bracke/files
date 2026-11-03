with GNAT.OS_Lib;

--  The shape a path must have before a helper is handed it or a record keeps
--  it. No disk is read, so the model can ask too; one rule, so the job
--  transports, the recovery records and the model cannot drift apart.
package Files.Path_Checks is

   --  Whether Value holds no NUL byte, which no path or record field may.
   --
   --  @param Value Text to check.
   --  @return True when Value has no NUL.
   function Nul_Free (Value : String) return Boolean is
     (for all Item of Value => Item /= ASCII.NUL);

   --  Whether Path is fit to hand to a helper or write into a record: not
   --  empty, at most Max_Length bytes, no NUL, absolute.
   --
   --  @param Path Candidate path.
   --  @param Max_Length The record's bound.
   --  @return True when Path is such a path.
   function Valid_Absolute_Path (Path : String; Max_Length : Natural := Natural'Last) return Boolean is
     (Path /= ""
      and then Path'Length <= Max_Length
      and then Nul_Free (Path)
      and then GNAT.OS_Lib.Is_Absolute_Path (Path));

end Files.Path_Checks;
