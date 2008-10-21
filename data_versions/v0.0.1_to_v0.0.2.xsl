<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
	<xsl:output method="xml"/>
	
	<xsl:template match="/">
    	<xsl:apply-templates />
    </xsl:template>
	
	<xsl:template match="universe">
		<kuiper major='0' minor='0' bug='2'>
			<xsl:copy-of select="."/>
		</kuiper>
	</xsl:template>
</xsl:stylesheet>