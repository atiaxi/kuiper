<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
				xmlns:fn="http://www.w3.org/2005/02/xpath-functions"
				version="1.0">
				
	<xsl:output method="xml" 
				version="1.0"
				encoding="iso-8859-1"
				indent="no"/>
	
	<xsl:variable name="lf" select="'\n'" />
	
	<xsl:template match="/">
    	<xsl:apply-templates select="kuiper"/>
    </xsl:template>
    
    <!-- Reversioning template -->
    <xsl:template match="kuiper">
    	<xsl:element name="kuiper">
    		<xsl:attribute name="major">0</xsl:attribute>
    		<xsl:attribute name="minor">0</xsl:attribute>
			<xsl:attribute name="bug">3</xsl:attribute>
			<xsl:text>
			</xsl:text>
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
					<xsl:element name="{name()}">
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