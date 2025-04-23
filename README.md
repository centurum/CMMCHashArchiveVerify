# CMMC Hash Archive Verification
Verifies file integrity within a ZIP archive by comparing contents to the hash log output of the CMMC hashing script.

## Assumptions
This script assumes that the hashing script from the [CMMC Hashing Guide v2](https://dodcio.defense.gov/Portals/0/Documents/CMMC/HashingGuidev2.pdf) has been run against a collection of evidence documents and immediately archived into a ZIP file. 

## Usage
Download the `Verify-CMMCArtifactHash.ps1` file and execute in Powershell providing, at minimum, the `-ArtifactLogPath` and `-ArtifactZipPath` parameters. Example:

```
.\Verify-CMMCArtifactHash.ps1 -ArtifactLogPath 'C:\Temp\CMMCAssessmentArtifacts.log' -ArtifactZipPath 'C:\Temp\CMMCAssessmentArtifacts.zip'
```
### Parameters
* **ArtifactLogPath:** The *.log output of the script from the CMMC Hashing Guide containing the list of evidence artificates. This is **not** the hash-of-hashes that contains one file (usually named `CMMCAssessmentLogHash.log`)
* **ArtifactZipPath:** The archive to verify against the Artifact Log.
* **BaseDirectory:** (Optional) The path which is not built into the archive, but is part of the hash output (explained below).
* **PreserveTemp:** (Optional) Switch which skips the clean-up of the extracted archive after verification. 

# Description
This script is intended to be used to verify the contents of an archived copy of CMMC Assessment evidence artifacts,
stored within a ZIP file. The script extracts the provided ZIP archive to a temp directory, computes the SHA256 hash 
of each file, and compares them to the pre-generated artifact log output of the CMMC Hashing Guide script. The script
provides visual verification of each file and provides a summary of any files which have failed verification. Optionally 
preserves the extraction within the temp directory.

The script should detect an archive which preserved the top-level folder (such as creating the archive through the Windows context menu). 

If the script is run without the BaseDirectory parameter it will _attempt_ to figure it out. 

An example hash-log excerpt:

```
Algorithm       Hash                                                                   Path
---------       ----                                                                   ----
SHA256          91EEC762D9AC66047A4B068A0DC315A492E67B10C7660011A920A7E1DA673E01       C:\Temp\CMMC-2025\2025-04-18 - Centurum Evidence\4.18.25-Centurum_EvidencePlanMatrix.xlsx
SHA256          C16BD66976EC4346212E2A0081CA22395A9A077AE78D6344F8E6DFFA99E37B4A       C:\Temp\CMMC-2025\2025-04-18 - Centurum Evidence\1-Multiple\4.17.25-Centurum_3.4.2 [a].docx
SHA256          D6F15F4C3197CA64F956E9EEC9ED5F12736CDE02F9A8DDF0A84F44F6C5530B94       C:\Temp\CMMC-2025\2025-04-18 - Centurum Evidence\1-Multiple\Acceptable Use Policy.pdf
...
SHA256          B1AD55D24E570840ED23A9332D2BB2DD7930C4336CF4E2DCA087C050F48D6EFA       C:\Temp\CMMC-2025\2025-04-18 - Centurum Evidence\Access Control\AC.L2-3.1.17[ab]_CCIS_03312025_Internet-only Wireless Connections.pdf
SHA256          DA38F3DB6601E3DEE323C771A24961DB5D4B88DD173623BD0D69D6264FEA7A06       C:\Temp\CMMC-2025\2025-04-18 - Centurum Evidence\Access Control\AC.L2-3.1.18[a]_CCIS_03302025_Inventory - Mobile Devices.csv
SHA256          F27A8C0B73E3D86C69B7A0E370C8B4513E1DDBFF8682148F1B474A7BD815C31C       C:\Temp\CMMC-2025\2025-04-18 - Centurum Evidence\Access Control\AC.L2-3.1.18[abc]_CCIS_03312025_Mobile Devices - Managed.pdf
```

In the above, the *base directory* would be `C:\Temp\CMMC-2025\2025-04-18 - Centurum Evidence\`. This is the part of the path which is not a part of the archive and needs to be normalized within the script.
