<resource schema="veritas_lc">

  <meta name="title">VERITAS-LC</meta>
  <meta name="description">
  The VERITAS lightcurves database.
  ---
  VERITAS-LCVO.alpha version
  </meta>
  <meta name="creationDate">2017-12-05T10:10:10Z</meta>
  <meta name="subject">lightcurves</meta>
  <meta name="subject">high energy astrophysics</meta>
  <meta name="subject">gamma rays</meta>

  <meta name="creator.name">Carlos Brandt</meta>
  <meta name="facility">VERITAS</meta>

  <!-- <meta name="source">
    VERITAS collaboration
  </meta> -->
  <meta name="contentLevel">Research</meta>
  <meta name="type">Archive</meta>

  <meta name="coverage">
    <meta name="waveband">Gamma-ray</meta>
    <meta name="profile">AllSky ICRS</meta>
  </meta>


  <!-- =============== -->
  <!--  Table block    -->
  <!-- =============== -->

  <table id="main" onDisk="True" adql="True">
    <mixin
      fluxCalibration="ABSOLUTE"
      fluxUnit="ph / (cm2 s)"
      fluxUCD="phot.flux"
      spectralUnit="d"
      spectralUCD="time.epoch"
      > //ssap#hcd
    </mixin>
    <column name="bibcode"
            type="text"
            tablehead="Reference"/>
    <column name="article"
            type="text"
            tablehead="Reference"/>
    <column name="ra"
            type="double precision"
            unit="deg" ucd="pos.eq.ra"
            tablehead="RA_J2000"
            verbLevel="20"
            description="Right Ascension"
            required="True"/>
    <column name="dec"
            type="double precision"
            unit="deg" ucd="pos.eq.dec"
            tablehead="DEC_J2000"
            verbLevel="20"
            description="Declination"
            required="True"/>
    <column name="activitytag"
            type="text"
            tablehead="Activity-tag"/>
  </table>


  <table id="spectrum">
    <mixin
      ssaTable="main"
      fluxDescription="Absolute Flux"
      spectralDescription="Epoch"
      > //ssap#sdm-instance
    </mixin>
    <!-- <column name="dnde_errp"
            ucd="stat.error;phot.flux">
      <values nullLiteral="-999"/>
    </column>
    <column name="dnde_errn"
            ucd="stat.error;phot.flux">
      <values nullLiteral="-999"/>
    </column> -->
    <!-- <column name="ssa_timeExt">
      <values nullLiteral="-999"/>
    </column> -->
  </table>


  <!-- =============== -->
  <!--  Data block     -->
  <!-- =============== -->

  <data id="import">
    <sources pattern='data/pub/*.fits' recurse="False" />

    <fitsProdGrammar hdu="1" qnd="False">
      <rowfilter procDef="//products#define">
        <bind name="table">"\schema.data"</bind>
      </rowfilter>
    </fitsProdGrammar>

    <make table="main">
      <rowmaker idmaps="*">
        <map key="bibcode">@ARTICLE_label</map>
        <map key="ra">@RA</map>
        <map key="dec">@DEC</map>
        <map key="article">@ARTICLE_url</map>
        <map key="activitytag">@COMMENTS_Tag</map>
        <apply procDef="//ssap#setMeta" name="setMeta">
          <bind key="pubDID">\standardPubDID</bind>
          <bind key="dstitle">@COMMENTS_Name</bind>
          <bind key="targname">@OBJECT</bind>
          <bind key="alpha">@RA</bind>
          <bind key="delta">@DEC</bind>
          <bind key="dateObs">@MJD_START + (@MJD_END-@MJD_START)/2</bind>
          <bind key="bandpass">"Gamma-ray"</bind>
          <bind key="redshift">@COMMENTS_Redshift</bind>
          <bind key="timeExt">@COMMENTS_LiveTime * 3600</bind>
          <bind key="length">@NAXIS2</bind>
        </apply>
        <apply procDef="//ssap#setMixcMeta" name="setMixcMeta">
          <bind key="reference">@ARTICLE_url</bind>
        </apply>
      </rowmaker>
    </make>

  </data>


  <data id="build_sdm_data" auto="False">

    <embeddedGrammar>
      <iterator>
        <setup>
          <code>
            from gavo.utils import pyfits
            from gavo.protocols import products
          </code>
        </setup>
        <code>
          fitsPath = products.RAccref.fromString(
                        self.sourceToken["accref"]).localpath
          hdu = pyfits.open(fitsPath)[1]
          for i,row in enumerate(hdu.data):
              yield {   "spectral"  : row[0],
                        "flux"      : row[1],
                        "flux_error": (row[2]+row[3])/2 }
        </code>
      </iterator>
    </embeddedGrammar>

    <make table="spectrum">
      <parmaker>
        <apply procDef="//ssap#feedSSAToSDM"/>
      </parmaker>
    </make>

  </data>


  <!-- =============== -->
  <!--  Service block  -->
  <!-- =============== -->

  <service id="web" defaultRenderer="form">
    <meta name="shortName">Veritas Web</meta>
    <meta name="title">VERITAS Spectra Web Interface</meta>

    <publish render="form" sets="local"/>

    <dbCore queriedTable="main">
      <condDesc buildFrom="ssa_location"/>
      <condDesc buildFrom="ssa_dateObs"/>
    </dbCore>

    <outputTable>
        <outputField original="ssa_targname"/>
        <outputField original="ssa_dateObs">
            <!-- <formatter>
                <![CDATA[
                    yield data
                ]]>
            </formatter> -->
        </outputField>
        <outputField original="accref"/>

      <!-- <FEED source="//ssap#atomicCoords"/> -->

      <outputField name="Article" select="array[article,bibcode]">
        <formatter><![CDATA[
          lbl = data[1]
          url = data[0]
          yield T.a(href="%s"%url , target="_blank")["%s"%lbl]
        ]]></formatter>
      </outputField>

      <outputField name="asdc_link" tablehead="ASDC Portal" select="array[ra,dec]">
        <formatter><![CDATA[
          _ra = data[0]
          _dec = data[1]
          url = 'http://tools.asdc.asi.it/SED/sed.jsp?&ra=%s&dec=%s' % (str(_ra),str(_dec))
          yield T.a(href="%s"%url , target="_blank")["ASDC SED tool"]
        ]]></formatter>
      </outputField>
    </outputTable>

  </service>

  <service id="ssa" allowed="ssap.xml">
    <meta name="shortName">Veritas SSAP</meta>
    <meta name="title">VERITAS Spectra SSAP Interface</meta>
    <meta name="ssap.dataSource">pointed</meta>
    <meta name="ssap.creationType">archival</meta>
    <meta name="ssap.testQuery">MAXREC=1</meta>

    <!-- <publish render="ssap.xml" sets="ivo_managed"/> -->

    <ssapCore queriedTable="main">
      <FEED source="//ssap#hcd_condDescs"/>
    </ssapCore>

  </service>

</resource>
