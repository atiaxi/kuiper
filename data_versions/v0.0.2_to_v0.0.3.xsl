<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
				xmlns:fn="http://www.w3.org/2005/02/xpath-functions"
				version="1.0">
<!-- According to the XML spec, I was never supposed to have newlines
     in attributes in the first place.  Ruby just let me get away with it.
     As such, this XSLT will not preserve them, and I'm going to have to 
     write a script to do so for this version -->				
	<xsl:output method="xml" 
				version="1.0"
				encoding="iso-8859-1"/>
	
	<xsl:template match="/">
    	<xsl:apply-templates select="kuiper"/>
    </xsl:template>
    
    <!-- Reversioning template -->
    <xsl:template match="kuiper">
    		<xsl:element name="kuiper">
    		<xsl:attribute name="major">0</xsl:attribute>
    		<xsl:attribute name="minor">0</xsl:attribute>
			<xsl:attribute name="bug">3</xsl:attribute>

			<xsl:apply-templates />
		</xsl:element>
	</xsl:template>
	
	<xsl:template match="kuiper/">
		<xsl:copy>
			<xsl:text>
			</xsl:text>
			<!-- Attributes to fields -->
			<fields>
				<xsl:text>
				</xsl:text>
				<xsl:for-each select="attribute::*">
					<xsl:element name="{name()}" >
						<xsl:value-of select="."/>
					</xsl:element>
				<xsl:text>
				</xsl:text>
				</xsl:for-each>
			</fields>
			<xsl:text>
			</xsl:text>
		</xsl:copy>
	</xsl:template>
	
</xsl:stylesheet>
